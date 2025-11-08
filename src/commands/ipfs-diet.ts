import { DatabaseService } from '../services/database';
import { IpfsService } from '../services/ipfs';
import { logger } from '../utils/logger';
import { config } from '../config';

interface IpfsDietOptions {
  olderThanMonths?: string;
  viewThreshold?: string;
  batchSize?: string;
  dryRun?: boolean;
  confirm?: boolean;
}

export async function ipfsDietCommand(options: IpfsDietOptions): Promise<void> {
  const db = new DatabaseService();
  const ipfsService = new IpfsService();
  const isDryRun = options.dryRun !== false; // Default to dry run for safety
  
  try {
    await db.connect();

    const olderThanMonths = options.olderThanMonths ? parseInt(options.olderThanMonths, 10) : 6;
    const viewThreshold = options.viewThreshold ? parseInt(options.viewThreshold, 10) : 500;
    const olderThanDays = olderThanMonths * 30;

    logger.info(`=== IPFS DIET: Unpin Low-Engagement IPFS Videos ===`);
    logger.info(`Target: IPFS videos older than ${olderThanMonths} months with <${viewThreshold} views`);
    logger.info(`Action: Unpin IPFS hashes to free up storage (videos become inaccessible)`);
    
    if (isDryRun) {
      logger.info('=== DRY RUN MODE - No changes will be made ===');
    } else {
      logger.info('⚠️  This will permanently unpin IPFS content!');
    }

    // Get low-engagement IPFS videos
    const videos = await db.getVideosByCriteria({
      type: 'low-engagement',
      olderThanDays,
      viewThreshold,
      storageType: 'ipfs', // Only IPFS videos can be unpinned
      limit: options.batchSize ? parseInt(options.batchSize, 10) : 25
    });

    if (videos.length === 0) {
      logger.info('No IPFS videos found matching criteria for IPFS diet');
      logger.info('💡 This is where most storage savings happen - old IPFS videos');
      return;
    }

    logger.info(`Found ${videos.length} IPFS videos for diet optimization`);

    if (isDryRun) {
      logger.info('=== DRY RUN ANALYSIS ===');
      
      const analysis = {
        videosToUnpin: 0,
        hashesToUnpin: [] as string[],
        totalCurrentSize: 0,
        estimatedSavings: 0
      };

      for (const video of videos) {
        const hash = IpfsService.extractHashFromFilename(video.filename || '');
        
        if (hash) {
          logger.info(`Would unpin: ${video._id} (${video.permlink})`);
          logger.info(`  Title: ${video.title || 'No title'}`);
          logger.info(`  Age: ${Math.floor((Date.now() - video.created.getTime()) / (1000 * 60 * 60 * 24))} days`);
          logger.info(`  Views: ${video.views || 0}`);
          logger.info(`  Size: ${((video.size || 0) / (1024 * 1024)).toFixed(2)} MB`);
          logger.info(`  IPFS Hash: ${hash}`);
          
          analysis.hashesToUnpin.push(hash);
          analysis.totalCurrentSize += video.size || 0;
          analysis.estimatedSavings += video.size || 0; // 100% freed when unpinned
          analysis.videosToUnpin++;
          
          logger.info(`  Status: Will be unpinned (becomes inaccessible)`);
        } else {
          logger.info(`Skipping ${video._id}: No IPFS hash found in filename`);
        }
        
        logger.info('---');
      }

      const currentSizeGB = (analysis.totalCurrentSize / (1024 * 1024 * 1024)).toFixed(2);
      const savingsGB = (analysis.estimatedSavings / (1024 * 1024 * 1024)).toFixed(2);
      const savingsTB = (analysis.estimatedSavings / (1024 * 1024 * 1024 * 1024)).toFixed(3);
      
      logger.info(`=== IPFS DIET PREVIEW ===`);
      logger.info(`IPFS videos to unpin: ${analysis.videosToUnpin}`);
      logger.info(`IPFS hashes to unpin: ${analysis.hashesToUnpin.length}`);
      logger.info(`Current total size: ${currentSizeGB} GB`);
      logger.info(`💾 ESTIMATED IPFS SAVINGS: ${savingsGB} GB (${savingsTB} TB) - 100% freed when unpinned`);
      logger.info(`⚠️  WARNING: Videos will become inaccessible after unpinning!`);
      logger.info(`Use --no-dry-run to execute the IPFS diet`);
      
      return;
    }

    // Real optimization mode
    if (config.safety.requireConfirmation && options.confirm !== false) {
      logger.info('IPFS diet requires explicit confirmation');
      logger.info('Use --no-confirm to skip confirmation (dangerous!)');
      return;
    }

    // Perform actual IPFS diet
    const batchSize = options.batchSize ? parseInt(options.batchSize, 10) : 25;
    logger.info(`Starting IPFS diet in batches of ${batchSize}`);

    const results = {
      processed: 0,
      hashesUnpinned: 0,
      totalStorageFreed: 0,
      errors: [] as string[]
    };

    // Process videos in batches
    for (let i = 0; i < videos.length; i += batchSize) {
      const batch = videos.slice(i, i + batchSize);
      logger.info(`Processing batch ${Math.floor(i / batchSize) + 1}/${Math.ceil(videos.length / batchSize)}`);

      for (const video of batch) {
        try {
          const hash = IpfsService.extractHashFromFilename(video.filename || '');
          
          if (!hash) {
            logger.info(`Skipping ${video._id}: No IPFS hash found`);
            continue;
          }
          
          const originalSize = video.size || 0;
          
          logger.info(`Unpinning: ${video._id} (${video.permlink})`);
          logger.info(`  IPFS Hash: ${hash}`);
          logger.info(`  Size: ${((originalSize) / (1024 * 1024)).toFixed(2)} MB`);
          
          // Unpin the IPFS hash
          const success = await ipfsService.unpinHash(hash);
          
          if (success) {
            results.hashesUnpinned++;
            results.totalStorageFreed += originalSize;
            
            logger.info(`✅ Unpinned ${video._id}: ${hash} (${((originalSize) / (1024 * 1024)).toFixed(2)} MB freed)`);
            
            // Mark video as cleaned up
            await db.markVideoAsCleanedUp(video._id, {
              cleanupDate: new Date(),
              cleanupReason: `IPFS diet: Unpinned low-engagement content (older than ${olderThanMonths} months, <${viewThreshold} views)`,
              storageType: 'ipfs',
              originalStatus: video.status,
              optimizationType: 'ipfs-diet-unpin'
            });
            
          } else {
            logger.error(`Failed to unpin ${video._id}: ${hash}`);
            results.errors.push(`Failed to unpin ${video._id}: ${hash}`);
          }

          results.processed++;

        } catch (error: any) {
          logger.error(`Error processing video ${video._id}`, error);
          results.errors.push(`Error processing ${video._id}: ${error.message}`);
        }
      }

      // Pause between batches to avoid overwhelming IPFS node
      if (i + batchSize < videos.length) {
        logger.info('Pausing between batches for IPFS stability...');
        await new Promise(resolve => setTimeout(resolve, 5000)); // 5 second pause for IPFS
      }
    }

    // Final results
    const storageFreedGB = (results.totalStorageFreed / (1024 * 1024 * 1024)).toFixed(2);
    const storageFreedTB = (results.totalStorageFreed / (1024 * 1024 * 1024 * 1024)).toFixed(3);
    
    logger.info('=== IPFS DIET COMPLETED ===');
    logger.info(`IPFS videos processed: ${results.processed}`);
    logger.info(`IPFS hashes unpinned: ${results.hashesUnpinned}`);
    logger.info(`🗂️ 💾 IPFS STORAGE FREED: ${storageFreedGB} GB (${storageFreedTB} TB)`);
    logger.info(`⚠️  Unpinned videos are no longer accessible via IPFS`);
    logger.info(`💡 Run 'ipfs repo gc' to actually free disk space`);
    logger.info(`Errors: ${results.errors.length}`);
    
    if (results.errors.length > 0) {
      logger.error('Errors encountered:');
      results.errors.forEach(error => logger.error(`  ${error}`));
    }
    
  } catch (error) {
    logger.error('IPFS diet command failed', error);
    throw error;
  } finally {
    await db.disconnect();
  }
}