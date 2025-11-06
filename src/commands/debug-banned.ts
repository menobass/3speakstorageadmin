import { DatabaseService } from '../services/database';
import { logger } from '../utils/logger';

export async function debugBannedUsersCommand(): Promise<void> {
  const db = new DatabaseService();
  
  try {
    await db.connect();
    
    // Step 1: Get banned users
    logger.info('=== Step 1: Getting banned users ===');
    const bannedUsers = await db.getBannedUsers();
    logger.info(`Found ${bannedUsers.length} banned users`);
    
    // Show first 5 banned users
    for (let i = 0; i < Math.min(5, bannedUsers.length); i++) {
      const user = bannedUsers[i];
      logger.info(`Banned user ${i + 1}: ${user.username}`);
    }
    
    // Step 2: Check if any videos have these usernames
    if (bannedUsers.length > 0) {
      const bannedUsernames = bannedUsers.map(user => user.username);
      logger.info('=== Step 2: Looking for videos with these usernames ===');
      
      // Check first banned username
      const firstUsername = bannedUsernames[0];
      logger.info(`Checking for videos with username: "${firstUsername}"`);
      
      const videosCollection = (db as any).getVideosCollection();
      const videosForFirstUser = await videosCollection.find({ username: firstUsername }).limit(5).toArray();
      
      logger.info(`Found ${videosForFirstUser.length} videos for user "${firstUsername}"`);
      
      if (videosForFirstUser.length === 0) {
        // Maybe the field is called 'owner' instead?
        logger.info(`Trying with 'owner' field instead...`);
        const videosWithOwner = await videosCollection.find({ owner: firstUsername }).limit(5).toArray();
        logger.info(`Found ${videosWithOwner.length} videos with owner: "${firstUsername}"`);
        
        // Let's see what fields a video actually has
        logger.info('=== Sample video fields ===');
        const sampleVideo = await videosCollection.findOne({});
        if (sampleVideo) {
          const relevantFields = {
            username: sampleVideo.username,
            owner: sampleVideo.owner,
            author: sampleVideo.author,
            _id: sampleVideo._id
          };
          logger.info('Sample video fields:', relevantFields);
        }
      }
      
      // Try with all banned usernames using username field
      logger.info('=== Step 3: Checking all banned users (username field) ===');
      const allVideosUsername = await videosCollection.find({ 
        username: { $in: bannedUsernames } 
      }).limit(10).toArray();
      logger.info(`Found ${allVideosUsername.length} videos using username field`);
      
      // Try with all banned usernames using owner field
      logger.info('=== Step 4: Checking all banned users (owner field) ===');
      const allVideosOwner = await videosCollection.find({ 
        owner: { $in: bannedUsernames } 
      }).limit(10).toArray();
      logger.info(`Found ${allVideosOwner.length} videos using owner field`);
    }
    
  } catch (error) {
    logger.error('Debug command failed', error);
    throw error;
  } finally {
    await db.disconnect();
  }
}