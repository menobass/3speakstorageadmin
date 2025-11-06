import { DatabaseService } from '../services/database';
import { CleanupCriteria } from '../types';
import { logger } from '../utils/logger';

interface ListOptions {
  bannedUsers?: boolean;
  age?: string;
  maxViews?: string;
  minViews?: string;
  orphaned?: boolean;
  status?: string;
  stuckDays?: string;
  storageType?: 'ipfs' | 's3' | 'unknown';
  limit?: string;
}

export async function listCommand(options: ListOptions): Promise<void> {
  const db = new DatabaseService();
  
  try {
    await db.connect();
    
    // Build criteria from options
    const criteria: CleanupCriteria = {};
    
    if (options.bannedUsers) criteria.bannedUsers = true;
    if (options.age) criteria.ageThresholdDays = parseInt(options.age, 10);
    if (options.maxViews) criteria.maxViews = parseInt(options.maxViews, 10);
    if (options.minViews) criteria.minViews = parseInt(options.minViews, 10);
    if (options.orphaned) criteria.orphaned = true;
    if (options.status) criteria.status = options.status.split(',').map(s => s.trim());
    if (options.stuckDays) criteria.stuckDays = parseInt(options.stuckDays, 10);
    if (options.storageType) criteria.storageType = options.storageType;

    // Get videos matching criteria (with reasonable limit to prevent hanging)
    const queryLimit = options.limit ? parseInt(options.limit, 10) : 1000;
    let videos = await db.getVideosByCriteria(criteria, Math.max(queryLimit, 1000));
    
    // Apply storage type filter if specified
    if (criteria.storageType) {
      videos = videos.filter(video => {
        const storageType = db.getVideoStorageType(video);
        return storageType === criteria.storageType;
      });
    }
    
    if (options.limit) {
      const limit = parseInt(options.limit, 10);
      videos = videos.slice(0, limit);
    }
    
    if (videos.length === 0) {
      logger.info('No videos found matching the specified criteria');
      return;
    }

    logger.info(`=== Found ${videos.length} videos ===`);
    
    videos.forEach(video => {
      logger.info(`ID: ${video._id}`);
      logger.info(`  Title: ${video.title || 'No title'}`);
      logger.info(`  Owner: ${video.owner}`);
      logger.info(`  Views: ${video.views}`);
      logger.info(`  Status: ${video.status}`);
      logger.info(`  Created: ${video.created.toISOString()}`);
      if (video.filename) {
        if (video.filename.startsWith('ipfs://')) {
          logger.info(`  IPFS: ${video.filename}`);
        } else {
          logger.info(`  S3 Filename: ${video.filename}`);
        }
      }
      if (video.permlink) logger.info(`  Permlink: ${video.permlink}`);
      if (video.originalFilename) logger.info(`  Original: ${video.originalFilename}`);
      logger.info('---');
    });
    
  } catch (error) {
    logger.error('List command failed', error);
    throw error;
  } finally {
    await db.disconnect();
  }
}