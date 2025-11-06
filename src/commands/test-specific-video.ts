import { S3Service } from '../services/s3';
import { logger } from '../utils/logger';

export async function testSpecificVideoCommand(): Promise<void> {
  const s3Service = new S3Service();
  
  try {
    logger.info('=== TESTING SPECIFIC VIDEO S3 OBJECT ===');
    
    // Eddie's video from your example
    const videoId = '5e76cc5b2e5ed559992e2753';
    const s3Key = 'GmjTmToyXMIXIPFfHuJMqbjlESuKUwQbXSRVVvlCtHuzjTRvuoQctvrmxrsaHuUE.mp4';
    
    logger.info(`Video ID: ${videoId}`);
    logger.info(`S3 Key: ${s3Key}`);
    logger.info(`Owner: eddiespino`);
    logger.info(`Title: Introduction to HIVE Blockchain and First Video on 3SpeakOnline`);
    
    // Test direct MP4 file
    logger.info('\n--- Testing Direct MP4 File ---');
    const mp4Exists = await s3Service.objectExists(s3Key);
    logger.info(`MP4 exists: ${mp4Exists}`);
    
    if (mp4Exists) {
      const info = await s3Service.getObjectInfo(s3Key);
      logger.info(`Size: ${info.size ? (info.size / (1024 * 1024)).toFixed(2) + ' MB' : 'Unknown'}`);
      logger.info(`Last modified: ${info.lastModified || 'Unknown'}`);
    }
    
    // Test PERMLINK-based storage paths (the real structure!)
    const permlink = 'ljjucxyi'; // Eddie's video permlink
    const permlinkPaths = [
      `${permlink}/1080p.m3u8`,
      `${permlink}/720p.m3u8`,
      `${permlink}/480p.m3u8`,
      `${permlink}/360p.m3u8`,
      `${permlink}/default.m3u8`,
      `${permlink}/thumbnails/`,
      `${permlink}/1080p/`,
      `${permlink}/`,
      permlink
    ];
    
    logger.info('\n--- Testing Permlink-Based Paths ---');
    for (const path of permlinkPaths) {
      logger.info(`Testing: ${path}`);
      const exists = await s3Service.objectExists(path);
      logger.info(`  Exists: ${exists}`);
      
      if (exists) {
        const info = await s3Service.getObjectInfo(path);
        logger.info(`  Size: ${info.size ? (info.size / (1024 * 1024)).toFixed(2) + ' MB' : 'Unknown'}`);
        logger.info('  ✅ FOUND ALTERNATIVE PATH!');
        break;
      }
    }
    
    // Search for objects with similar patterns
    logger.info('\n--- Searching for Eddie\'s Content ---');
    const allObjects = await s3Service.listObjects('', 1000);
    const eddieObjects = allObjects.filter(obj => 
      obj.toLowerCase().includes('eddie') || 
      obj.includes('ljjucxyi') ||
      obj.includes('eifrzmtx') ||
      obj.toLowerCase().includes('gmjt')
    );
    
    logger.info(`Found ${eddieObjects.length} objects potentially related to Eddie:`);
    eddieObjects.forEach(obj => {
      logger.info(`  ${obj}`);
    });
    
  } catch (error) {
    logger.error('Test failed', error);
  }
}