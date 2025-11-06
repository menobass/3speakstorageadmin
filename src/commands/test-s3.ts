import { S3Service } from '../services/s3';
import { DatabaseService } from '../services/database';
import { logger } from '../utils/logger';

export async function testS3Command(): Promise<void> {
  const s3Service = new S3Service();
  const db = new DatabaseService();
  
  try {
    await db.connect();
    
    logger.info('=== S3 CONNECTION TEST ===');
    
    // Test 1: Get S3 service info
    const serviceInfo = await s3Service.getServiceInfo();
    logger.info(`Bucket: ${serviceInfo.bucketName}`);
    logger.info(`Endpoint: ${serviceInfo.endpoint}`);
    logger.info(`Region: ${serviceInfo.region}`);
    logger.info(`Accessible: ${serviceInfo.accessible}`);
    
    if (!serviceInfo.accessible) {
      logger.error('S3 service is not accessible!');
      return;
    }
    
    // Test 2: List some objects in the bucket
    logger.info('\n=== LISTING S3 OBJECTS ===');
    const objects = await s3Service.listObjects('', 20);
    logger.info(`Found ${objects.length} objects in bucket:`);
    objects.forEach((key, index) => {
      logger.info(`  ${index + 1}. ${key}`);
    });
    
    if (objects.length === 0) {
      logger.warn('No objects found in bucket!');
      return;
    }
    
    // Test 3: Check if a specific object exists (first one from list)
    if (objects.length > 0) {
      const testKey = objects[0];
      logger.info(`\n=== TESTING OBJECT EXISTENCE ===`);
      logger.info(`Testing object: ${testKey}`);
      
      const exists = await s3Service.objectExists(testKey);
      logger.info(`Object exists: ${exists}`);
      
      if (exists) {
        const info = await s3Service.getObjectInfo(testKey);
        logger.info(`Size: ${info.size ? (info.size / (1024 * 1024)).toFixed(2) + ' MB' : 'Unknown'}`);
        logger.info(`Last modified: ${info.lastModified || 'Unknown'}`);
      }
    }
    
    // Test 4: Find a published video with filename and test its S3 object
    logger.info('\n=== TESTING PUBLISHED VIDEO S3 OBJECT ===');
    const publishedVideos = await db.getVideosByCriteria({
      status: ['published']
    });
      
    // Filter for S3 videos (not IPFS)
    const s3Videos = publishedVideos
      .filter(video => video.filename && !video.filename.startsWith('ipfs://'))
      .slice(0, 5);
    
    logger.info(`Found ${s3Videos.length} published videos with S3 filenames`);
    
    for (const video of s3Videos.slice(0, 3)) {
      const s3Key = db.getS3Filename(video);
      if (s3Key) {
        logger.info(`\nTesting video: ${video._id}`);
        logger.info(`  Title: ${video.title || 'No title'}`);
        logger.info(`  S3 Key: ${s3Key}`);
        
        const exists = await s3Service.objectExists(s3Key);
        logger.info(`  Exists: ${exists}`);
        
        if (exists) {
          const info = await s3Service.getObjectInfo(s3Key);
          logger.info(`  Size: ${info.size ? (info.size / (1024 * 1024)).toFixed(2) + ' MB' : 'Unknown'}`);
          logger.info('  ✅ S3 connection working - this object exists!');
          break;
        } else {
          logger.info('  ❌ Object not found');
        }
      }
    }
    
  } catch (error) {
    logger.error('S3 test failed', error);
  } finally {
    await db.disconnect();
  }
}