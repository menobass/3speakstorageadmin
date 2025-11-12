import { DatabaseService } from '../services/database';
import { IpfsService } from '../services/ipfs';
import { Video } from '../types';
import { logger } from '../utils/logger';
import { config } from '../config';
import { ProgressBar } from '../utils/progress';

interface PurgeAbandonedOptions {
  dryRun?: boolean;
  confirm?: boolean;
  batchSize?: string;
  limit?: string;
  olderThanDays?: string;
}

export async function purgeAbandonedCommand(options: PurgeAbandonedOptions): Promise<void> {
  const db = new DatabaseService();
  const ipfsService = new IpfsService();
  const isDryRun = options.dryRun !== false; // Default to true unless --no-dry-run is specified
  
  try {
    await db.connect();

    const limit = options.limit ? parseInt(options.limit, 10) : 0;
    const batchSize = options.batchSize ? parseInt(options.batchSize, 10) : 100;
    const olderThanDays = options.olderThanDays ? parseInt(options.olderThanDays, 10) : 7;

    logger.info(`=== PURGE ABANDONED MANUAL PUBLISH VIDEOS ===`);
    logger.info(`Target: Videos stuck in 'publish_manual' status for ${olderThanDays}+ days`);
    logger.info(`Action: Mark as deleted and unpin from IPFS`);
    
    if (isDryRun) {
      logger.info('=== DRY RUN MODE - No changes will be made ===');
    } else {
      logger.info('⚠️  This will mark videos as deleted and unpin IPFS content!');
    }

    // Get abandoned publish_manual videos
    logger.info('🔍 Finding abandoned publish_manual videos...');
    const videos = await db.getVideosByCriteria({
      status: ['publish_manual'],
      ageThresholdDays: olderThanDays
    }, limit || 10000);

    if (videos.length === 0) {
      logger.info(`No abandoned publish_manual videos found (older than ${olderThanDays} days)`);
      return;
    }

    logger.info(`Found ${videos.length} abandoned publish_manual videos`);

    if (isDryRun) {
      logger.info('=== DRY RUN ANALYSIS ===');
      
      // Analyze the videos
      const storageCounts = { ipfs: 0, s3: 0, unknown: 0 };
      let totalSize = 0;
      let oldestVideo: Video | null = null;
      let oldestAge = 0;

      for (const video of videos) {
        const storageType = db.getVideoStorageType(video);
        storageCounts[storageType]++;
        
        totalSize += video.size || 0;
        
        const ageInDays = Math.floor((Date.now() - video.created.getTime()) / (1000 * 60 * 60 * 24));
        if (ageInDays > oldestAge) {
          oldestAge = ageInDays;
          oldestVideo = video;
        }
      }

      logger.info(`=== ABANDONED VIDEOS PURGE PREVIEW ===`);
      logger.info(`Total abandoned videos: ${videos.length}`);
      logger.info(`Age threshold: ${olderThanDays} days`);
      logger.info(`Oldest video: ${oldestAge} days old`);
      logger.info(`Total size: ${(totalSize / (1024 ** 3)).toFixed(2)} GB`);
      logger.info(`Storage breakdown:`);
      logger.info(`  - IPFS: ${storageCounts.ipfs} videos (will be unpinned)`);
      logger.info(`  - S3: ${storageCounts.s3} videos (already deleted from storage)`);
      logger.info(`  - Unknown: ${storageCounts.unknown} videos`);
      logger.info(`💡 These videos have been stuck in manual publish for too long`);
      logger.info(`💡 All videos will be marked as 'deleted' status`);
      logger.info(`Use --no-dry-run to execute the abandoned videos purge`);
      
      return;
    }

    // Real purge mode
    if (!isDryRun && config.safety.requireConfirmation && options.confirm !== false) {
      logger.info('Abandoned videos purge requires explicit confirmation');
      logger.info('Use --no-confirm to skip confirmation (dangerous!)');
      return;
    }

    // Perform actual abandoned videos purge
    logger.info(`Starting abandoned videos purge in batches of ${batchSize}`);

    const results = {
      processed: 0,
      markedAsDeleted: 0,
      ipfsUnpinned: 0,
      totalStorageFreed: 0,
      errors: [] as string[]
    };

    const progressBar = new ProgressBar(videos.length, 'Purging abandoned videos');

    // Process videos in batches
    for (let i = 0; i < videos.length; i += batchSize) {
      const batch = videos.slice(i, i + batchSize);
      logger.info(`Processing batch ${Math.floor(i / batchSize) + 1}/${Math.ceil(videos.length / batchSize)}`);

      for (const video of batch) {
        try {
          const storageType = db.getVideoStorageType(video);
          const originalSize = video.size || 0;
          const ageInDays = Math.floor((Date.now() - video.created.getTime()) / (1000 * 60 * 60 * 24));
          
          // Handle IPFS unpinning for IPFS videos
          if (storageType === 'ipfs') {
            const hash = IpfsService.extractHashFromFilename(video.filename || '');
            if (hash) {
              logger.info(`Unpinning abandoned IPFS video: ${video._id} (${ageInDays} days old, ${hash})`);
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
            cleanupReason: `Abandoned manual publish purge: Video stuck in 'publish_manual' for ${ageInDays} days`,
            storageType,
            originalStatus: video.status || 'publish_manual'
          });

          results.markedAsDeleted++;
          results.processed++;

          progressBar.increment(`${video._id} - purged (${ageInDays}d old, ${storageType})`);

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

    progressBar.complete('Abandoned videos purge completed');

    const storageFreedGB = (results.totalStorageFreed / (1024 ** 3)).toFixed(2);

    logger.info('=== ABANDONED VIDEOS PURGE COMPLETED ===');
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

    logger.info('💡 Abandoned videos cleaned up - storage freed for active content');
    
  } catch (error) {
    logger.error('Abandoned videos purge command failed', error);
    throw error;
  } finally {
    await db.disconnect();
  }
}