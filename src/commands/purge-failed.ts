import { DatabaseService } from '../services/database';
import { IpfsService } from '../services/ipfs';
import { Video } from '../types';
import { logger } from '../utils/logger';
import { config } from '../config';
import { ProgressBar } from '../utils/progress';

interface PurgeFailedOptions {
  dryRun?: boolean;
  confirm?: boolean;
  batchSize?: string;
  limit?: string;
}

export async function purgeFailedCommand(options: PurgeFailedOptions): Promise<void> {
  const db = new DatabaseService();
  const ipfsService = new IpfsService();
  const isDryRun = options.dryRun !== false; // Default to true unless --no-dry-run is specified
  
  try {
    await db.connect();

    const limit = options.limit ? parseInt(options.limit, 10) : 0;
    const batchSize = options.batchSize ? parseInt(options.batchSize, 10) : 100;

    logger.info(`=== PURGE FAILED VIDEOS ===`);
    logger.info(`Target: Videos with failed encoding/processing status`);
    logger.info(`Action: Mark as deleted and unpin from IPFS`);
    
    if (isDryRun) {
      logger.info('=== DRY RUN MODE - No changes will be made ===');
    } else {
      logger.info('⚠️  This will mark videos as deleted and unpin IPFS content!');
    }

    // Get failed videos (encoding_failed, failed, ipfs_pinning_failed)
    logger.info('🔍 Finding failed videos in database...');
    const videos = await db.getVideosByCriteria({
      status: ['encoding_failed', 'failed', 'ipfs_pinning_failed']
    }, limit || 10000);

    if (videos.length === 0) {
      logger.info('No failed videos found in database');
      return;
    }

    logger.info(`Found ${videos.length} failed videos in database`);

    if (isDryRun) {
      logger.info('=== DRY RUN ANALYSIS ===');
      
      // Count by status and storage type
      const statusCounts: Record<string, number> = {};
      const storageCounts = { ipfs: 0, s3: 0, unknown: 0 };
      let totalSize = 0;

      for (const video of videos) {
        const status = video.status || 'unknown';
        statusCounts[status] = (statusCounts[status] || 0) + 1;
        
        const storageType = db.getVideoStorageType(video);
        storageCounts[storageType]++;
        
        totalSize += video.size || 0;
      }

      logger.info(`=== FAILED VIDEOS PURGE PREVIEW ===`);
      logger.info(`Total failed videos: ${videos.length}`);
      logger.info(`Total size: ${(totalSize / (1024 ** 3)).toFixed(2)} GB`);
      logger.info(`Status breakdown:`);
      Object.entries(statusCounts).forEach(([status, count]) => {
        logger.info(`  - ${status}: ${count} videos`);
      });
      logger.info(`Storage breakdown:`);
      logger.info(`  - IPFS: ${storageCounts.ipfs} videos (will be unpinned)`);
      logger.info(`  - S3: ${storageCounts.s3} videos (already deleted from storage)`);
      logger.info(`  - Unknown: ${storageCounts.unknown} videos`);
      logger.info(`💡 All videos will be marked as 'deleted' status`);
      logger.info(`Use --no-dry-run to execute the failed videos purge`);
      
      return;
    }

    // Real purge mode
    if (!isDryRun && config.safety.requireConfirmation && options.confirm !== false) {
      logger.info('Failed videos purge requires explicit confirmation');
      logger.info('Use --no-confirm to skip confirmation (dangerous!)');
      return;
    }

    // Perform actual failed videos purge
    logger.info(`Starting failed videos purge in batches of ${batchSize}`);

    const results = {
      processed: 0,
      markedAsDeleted: 0,
      ipfsUnpinned: 0,
      totalStorageFreed: 0,
      errors: [] as string[]
    };

    const progressBar = new ProgressBar(videos.length, 'Purging failed videos');

    // Process videos in batches
    for (let i = 0; i < videos.length; i += batchSize) {
      const batch = videos.slice(i, i + batchSize);
      logger.info(`Processing batch ${Math.floor(i / batchSize) + 1}/${Math.ceil(videos.length / batchSize)}`);

      for (const video of batch) {
        try {
          const storageType = db.getVideoStorageType(video);
          const originalSize = video.size || 0;
          
          // Handle IPFS unpinning for IPFS videos
          if (storageType === 'ipfs') {
            const hash = IpfsService.extractHashFromFilename(video.filename || '');
            if (hash) {
              logger.info(`Unpinning IPFS video: ${video._id} (${hash})`);
              const success = await ipfsService.unpinHash(hash);
              if (success) {
                results.ipfsUnpinned++;
                results.totalStorageFreed += originalSize;
                logger.info(`✅ Unpinned IPFS hash: ${hash}`);
              } else {
                logger.warn(`Failed to unpin IPFS hash: ${hash}`);
              }
            }
          }

          // Mark video as deleted
          await db.updateVideoStatus(video._id, 'deleted');
          
          // Add cleanup metadata
          await db.markVideoAsCleanedUp(video._id, {
            cleanupDate: new Date(),
            cleanupReason: `Failed video purge: Original status '${video.status}' - marked as deleted`,
            storageType,
            originalStatus: video.status || 'unknown'
          });

          results.markedAsDeleted++;
          results.processed++;

          progressBar.increment(`${video._id} - purged (${storageType})`);

        } catch (error: any) {
          logger.error(`Error processing video ${video._id}`, error);
          results.errors.push(`Error processing ${video._id}: ${error.message}`);
          results.processed++;
          progressBar.increment(`${video._id} - error`);
        }
      }

      // Small pause between batches
      if (i + batchSize < videos.length) {
        await new Promise(resolve => setTimeout(resolve, 500));
      }
    }

    progressBar.complete('Failed videos purge completed');

    const storageFreedGB = (results.totalStorageFreed / (1024 ** 3)).toFixed(2);

    logger.info('=== FAILED VIDEOS PURGE COMPLETED ===');
    logger.info(`Videos processed: ${results.processed}`);
    logger.info(`🗑️ Marked as deleted: ${results.markedAsDeleted}`);
    logger.info(`📌 IPFS hashes unpinned: ${results.ipfsUnpinned}`);
    logger.info(`💾 IPFS storage freed: ${storageFreedGB} GB`);
    logger.info(`Errors: ${results.errors.length}`);

    if (results.errors.length > 0) {
      logger.error('Errors encountered during purge:');
      results.errors.slice(0, 10).forEach(err => logger.error(`  - ${err}`));
      if (results.errors.length > 10) {
        logger.error(`  ... and ${results.errors.length - 10} more errors`);
      }
    }

    logger.info('💡 Failed videos cleaned up - no longer cluttering the system');
    
  } catch (error) {
    logger.error('Failed videos purge command failed', error);
    throw error;
  } finally {
    await db.disconnect();
  }
}