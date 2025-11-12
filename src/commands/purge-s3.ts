import { DatabaseService } from '../services/database';
import { S3Service } from '../services/s3';
import { Video } from '../types';
import { logger } from '../utils/logger';
import { config } from '../config';
import { ProgressBar } from '../utils/progress';

interface PurgeS3Options {
  dryRun?: boolean;
  confirm?: boolean;
  batchSize?: string;
  limit?: string;
}

export async function purgeS3Command(options: PurgeS3Options): Promise<void> {
  const db = new DatabaseService();
  const s3Service = new S3Service();
  const isDryRun = options.dryRun === true; // Only dry run if explicitly requested
  
  try {
    await db.connect();

    const limit = options.limit ? parseInt(options.limit, 10) : 0;
    const batchSize = options.batchSize ? parseInt(options.batchSize, 10) : 100;

    logger.info(`=== S3 PURGE: Mark Deleted S3 Videos ===`);
    logger.info(`Target: S3 videos that no longer exist in storage`);
    logger.info(`Action: Mark videos as 'deleted' status in database`);
    
    if (isDryRun) {
      logger.info('=== DRY RUN MODE - No changes will be made ===');
    } else {
      logger.info('⚠️  This will update video statuses in the database!');
    }

    // Get all S3 videos from database
    logger.info('🔍 Finding S3 videos in database...');
    const videos = await db.getVideosByCriteria({
      storageType: 's3'
    }, limit || 1000); // Reasonable default limit

    if (videos.length === 0) {
      logger.info('No S3 videos found in database');
      return;
    }

    logger.info(`Found ${videos.length} S3 videos in database`);

    if (isDryRun) {
      logger.info('=== DRY RUN ANALYSIS ===');
      
      const analysis = {
        videosToCheck: videos.length,
        existingVideos: 0,
        missingVideos: 0,
        alreadyDeleted: 0,
        checkedCount: 0,
        errors: [] as string[]
      };

      const progressBar = new ProgressBar(Math.min(videos.length, 20), 'Analyzing S3 videos');

      // Check a sample of videos to estimate the scope
      const sampleSize = Math.min(videos.length, 20);
      for (let i = 0; i < sampleSize; i++) {
        const video = videos[i];
        
        try {
          // Check if already marked as deleted
          if (video.status === 'deleted') {
            analysis.alreadyDeleted++;
            progressBar.increment(`${video._id} - already deleted`);
            continue;
          }

          const s3Paths = db.getS3Paths(video);
          let videoExists = false;

          // Check if any S3 files exist for this video
          for (const filePath of s3Paths.files) {
            if (await s3Service.objectExists(filePath)) {
              videoExists = true;
              break;
            }
          }

          if (videoExists) {
            analysis.existingVideos++;
            progressBar.increment(`${video._id} - exists`);
          } else {
            analysis.missingVideos++;
            progressBar.increment(`${video._id} - missing`);
          }

          analysis.checkedCount++;
        } catch (error: any) {
          analysis.errors.push(`Error checking ${video._id}: ${error.message}`);
          progressBar.increment(`${video._id} - error`);
        }
      }

      progressBar.complete('Sample analysis completed');

      const missingPercentage = (analysis.missingVideos / analysis.checkedCount * 100).toFixed(1);
      const estimatedMissing = Math.round(videos.length * (analysis.missingVideos / analysis.checkedCount));

      logger.info(`=== S3 PURGE PREVIEW (based on ${sampleSize} video sample) ===`);
      logger.info(`Total S3 videos in database: ${videos.length}`);
      logger.info(`Sample checked: ${analysis.checkedCount}`);
      logger.info(`Sample existing in S3: ${analysis.existingVideos}`);
      logger.info(`Sample missing from S3: ${analysis.missingVideos} (${missingPercentage}%)`);
      logger.info(`Already deleted: ${analysis.alreadyDeleted}`);
      logger.info(`📊 ESTIMATED: ~${estimatedMissing} videos missing from S3`);
      logger.info(`These videos would be marked as 'deleted' status`);
      logger.info(`Use --no-dry-run to execute the S3 purge`);
      
      if (analysis.errors.length > 0) {
        logger.warn(`Errors during sample check: ${analysis.errors.length}`);
        analysis.errors.slice(0, 5).forEach(error => logger.warn(`  ${error}`));
      }
      
      return;
    }

    // Real purge mode
    if (config.safety.requireConfirmation && options.confirm !== false) {
      logger.info('S3 purge requires explicit confirmation');
      logger.info('Use --no-confirm to skip confirmation (dangerous!)');
      return;
    }

    // Perform actual S3 purge
    logger.info(`Starting S3 purge in batches of ${batchSize}`);

    const results = {
      processed: 0,
      alreadyDeleted: 0,
      stillExists: 0,
      markedAsDeleted: 0,
      errors: [] as string[]
    };

    const progressBar = new ProgressBar(videos.length, 'Purging S3 videos');

    // Process videos in batches
    for (let i = 0; i < videos.length; i += batchSize) {
      const batch = videos.slice(i, i + batchSize);
      logger.info(`Processing batch ${Math.floor(i / batchSize) + 1}/${Math.ceil(videos.length / batchSize)}`);

      for (const video of batch) {
        try {
          // Skip if already deleted
          if (video.status === 'deleted') {
            results.alreadyDeleted++;
            results.processed++;
            progressBar.increment(`${video._id} - skip (deleted)`);
            continue;
          }

          const s3Paths = db.getS3Paths(video);
          let videoExists = false;

          // Check if any S3 files exist for this video
          for (const filePath of s3Paths.files) {
            if (await s3Service.objectExists(filePath)) {
              videoExists = true;
              break;
            }
          }

          if (videoExists) {
            results.stillExists++;
            progressBar.increment(`${video._id} - exists`);
          } else {
            // Mark as deleted in database
            await db.updateVideoStatus(video._id, 'deleted');
            results.markedAsDeleted++;
            progressBar.increment(`${video._id} - marked deleted`);
          }

          results.processed++;

        } catch (error: any) {
          logger.error(`Error processing video ${video._id}`, error);
          results.errors.push(`Error processing ${video._id}: ${error.message}`);
          results.processed++;
          progressBar.increment(`${video._id} - error`);
        }
      }

      // Pause between batches to avoid overwhelming S3
      if (i + batchSize < videos.length) {
        logger.info('Pausing between batches for S3 stability...');
        await new Promise(resolve => setTimeout(resolve, 2000)); // 2 second pause
      }
    }

    progressBar.complete('S3 purge completed');

    logger.info('=== S3 PURGE COMPLETED ===');
    logger.info(`Videos processed: ${results.processed}`);
    logger.info(`Already deleted: ${results.alreadyDeleted}`);
    logger.info(`Still exist in S3: ${results.stillExists}`);
    logger.info(`🗑️ Marked as deleted: ${results.markedAsDeleted}`);
    logger.info(`Errors: ${results.errors.length}`);

    if (results.errors.length > 0) {
      logger.error('Errors encountered during purge:');
      results.errors.slice(0, 10).forEach(err => logger.error(`  - ${err}`));
      if (results.errors.length > 10) {
        logger.error(`  ... and ${results.errors.length - 10} more errors`);
      }
    }

    logger.info('💡 Videos marked as deleted can now be cleaned up with the cleanup command');
    
  } catch (error) {
    logger.error('S3 purge command failed', error);
    throw error;
  } finally {
    await db.disconnect();
  }
}