import { DatabaseService } from '../services/database';
import { IpfsService } from '../services/ipfs';
import { S3Service } from '../services/s3';
import { Video } from '../types';
import { logger } from '../utils/logger';
import { config } from '../config';
import { ProgressBar } from '../utils/progress';

interface NukeAccountOptions {
  username?: string;
  dryRun?: boolean;
  confirm?: boolean;
  batchSize?: string;
  includeCleaned?: boolean;
  limit?: string;
  status?: string;
}

const IPFS_HASH_REGEX = /^Qm[1-9A-HJ-NP-Za-km-z]{44}$/;

function formatBytes(bytes: number): { gb: string; tb: string } {
  const gb = (bytes / (1024 ** 3)).toFixed(2);
  const tb = (bytes / (1024 ** 4)).toFixed(3);
  return { gb, tb };
}

function collectIpfsHashes(video: Video): string[] {
  const hashes = new Set<string>();
  const candidates: Array<string | undefined | null> = [
    (video as any).ipfshash,
    video.filename,
    video.video_v2,
    (video as any).video_v1,
    (video as any).videoManifest,
  ];

  for (const candidate of candidates) {
    if (!candidate || typeof candidate !== 'string') {
      continue;
    }
    const extracted = IpfsService.extractHashFromFilename(candidate);
    if (extracted && IPFS_HASH_REGEX.test(extracted)) {
      hashes.add(extracted);
      continue;
    }
    const trimmed = candidate.trim();
    if (IPFS_HASH_REGEX.test(trimmed)) {
      hashes.add(trimmed);
    }
  }

  return Array.from(hashes);
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

export async function nukeAccountCommand(options: NukeAccountOptions): Promise<void> {
  const username = options.username?.trim();
  if (!username) {
    logger.error('The --username option is required for nuke-account');
    return;
  }

  const includeCleaned = options.includeCleaned === true;
  const limit = options.limit ? parseInt(options.limit, 10) : 0;
  if (options.limit && (Number.isNaN(limit) || limit < 0)) {
    logger.error('Invalid limit specified. Please provide a positive number.');
    return;
  }

  const batchSizeInput = options.batchSize ? parseInt(options.batchSize, 10) : 25;
  if (Number.isNaN(batchSizeInput) || batchSizeInput <= 0) {
    logger.error('Invalid batch size specified. Please provide a positive number.');
    return;
  }
  const batchSize = Math.min(batchSizeInput, 500);
  if (batchSizeInput > 500) {
    logger.warn(`Batch size capped at 500 for safety. Using ${batchSize}.`);
  }

  const statusFilter = options.status
    ? options.status.split(',').map(status => status.trim()).filter(Boolean)
    : undefined;

  const db = new DatabaseService();
  const ipfsService = new IpfsService();
  const s3Service = new S3Service();

  try {
    await db.connect();

    const videos = await db.getVideosByOwner(username, {
      includeCleaned,
      limit,
      statuses: statusFilter,
    });

    if (videos.length === 0) {
      logger.info(`No videos found for account ${username}. Nothing to do.`);
      return;
    }

    const statusCounts: Record<string, number> = {};
    const storageCounts: Record<'ipfs' | 's3' | 'unknown', number> = {
      ipfs: 0,
      s3: 0,
      unknown: 0,
    };
    const uniqueS3Files = new Set<string>();
    const uniqueS3Prefixes = new Set<string>();
    const uniqueIpfsHashes = new Set<string>();

    let totalBytes = 0;
    let alreadyCleaned = 0;

    videos.forEach(video => {
      const statusKey = video.status || 'unknown';
      statusCounts[statusKey] = (statusCounts[statusKey] || 0) + 1;

      const storageType = db.getVideoStorageType(video);
      storageCounts[storageType] = (storageCounts[storageType] || 0) + 1;

      if (video.cleanedUp) {
        alreadyCleaned++;
      }

      totalBytes += video.size || 0;

      const s3Paths = db.getS3Paths(video);
      s3Paths.files.forEach(path => uniqueS3Files.add(path));
      s3Paths.prefixes.forEach(prefix => uniqueS3Prefixes.add(prefix));

      collectIpfsHashes(video).forEach(hash => uniqueIpfsHashes.add(hash));
    });

    const { gb, tb } = formatBytes(totalBytes);

    logger.info('=== NUKE ACCOUNT SUMMARY ===');
    logger.info(`Target account: ${username}`);
    logger.info(`Total videos found: ${videos.length}`);
    logger.info(`Already marked as cleaned: ${alreadyCleaned}`);
    logger.info(`Recorded storage size: ${gb} GB (${tb} TB)`);
    logger.info(`Storage types -> S3: ${storageCounts.s3}, IPFS: ${storageCounts.ipfs}, Unknown: ${storageCounts.unknown}`);
    logger.info(`Unique S3 files targeted: ${uniqueS3Files.size}`);
    logger.info(`Unique S3 prefixes targeted: ${uniqueS3Prefixes.size}`);
    logger.info(`Unique IPFS hashes targeted: ${uniqueIpfsHashes.size}`);
    logger.info('Status breakdown:');
    Object.entries(statusCounts).forEach(([status, count]) => {
      logger.info(`  - ${status}: ${count}`);
    });

    const sampleSize = Math.min(5, videos.length);
    if (sampleSize > 0) {
      logger.info('Sample videos:');
      for (let i = 0; i < sampleSize; i++) {
        const video = videos[i];
        const title = video.title || video.permlink || video._id;
        logger.info(`  ${i + 1}. ${title} | status=${video.status} | size=${((video.size || 0) / (1024 ** 2)).toFixed(2)} MB`);
      }
    }

    if (options.dryRun) {
      logger.info('Dry run completed. No changes were made.');
      logger.info('Re-run with --no-confirm (and without --dry-run) to execute the account nuke.');
      return;
    }

    if (config.safety.requireConfirmation && options.confirm !== false) {
      logger.info('Confirmation required. Re-run with --no-confirm to execute this destructive operation.');
      return;
    }

    logger.warn(`Proceeding to permanently delete all videos for account ${username}`);
    logger.warn('This will delete S3 objects, unpin IPFS hashes, and mark all videos as deleted.');

    const results = {
      processed: 0,
      batches: 0,
      s3ObjectsDeleted: 0,
      ipfsHashesUnpinned: 0,
      dbUpdated: 0,
      totalStorageBytes: 0,
      errors: [] as string[],
      skippedDuplicates: 0,
    };

    const processedS3Files = new Set<string>();
    const processedS3Prefixes = new Set<string>();
    const processedIpfsHashes = new Set<string>();

    const progressBar = new ProgressBar(videos.length, `Nuking ${username}`);

    for (let i = 0; i < videos.length; i += batchSize) {
      const batch = videos.slice(i, i + batchSize);
      results.batches++;
      logger.info(`Processing batch ${results.batches}/${Math.ceil(videos.length / batchSize)} (${batch.length} videos)`);

      for (const video of batch) {
        try {
          const label = (video.title || video.permlink || video._id).substring(0, 40);
          const storageType = db.getVideoStorageType(video);

          const s3Paths = db.getS3Paths(video);
          for (const filePath of s3Paths.files) {
            if (!filePath || processedS3Files.has(filePath)) {
              if (processedS3Files.has(filePath)) {
                results.skippedDuplicates++;
              }
              continue;
            }
            processedS3Files.add(filePath);
            const success = await s3Service.deleteObject(filePath);
            if (success) {
              results.s3ObjectsDeleted++;
            }
          }

          for (const prefix of s3Paths.prefixes) {
            if (!prefix || processedS3Prefixes.has(prefix)) {
              if (processedS3Prefixes.has(prefix)) {
                results.skippedDuplicates++;
              }
              continue;
            }
            processedS3Prefixes.add(prefix);
            const outcome = await s3Service.deleteObjectsWithPrefix(prefix);
            results.s3ObjectsDeleted += outcome.deleted;
          }

          const ipfsHashes = collectIpfsHashes(video);
          for (const hash of ipfsHashes) {
            if (processedIpfsHashes.has(hash)) {
              results.skippedDuplicates++;
              continue;
            }
            processedIpfsHashes.add(hash);
            const success = await ipfsService.unpinHash(hash);
            if (success) {
              results.ipfsHashesUnpinned++;
            }
          }

          const cleanupReason = `nuke-account:${username}`;
          await db.markVideoAsCleanedUp(video._id, {
            cleanupDate: new Date(),
            cleanupReason,
            storageType,
            originalStatus: video.status,
          });
          results.dbUpdated++;
          results.totalStorageBytes += video.size || 0;
          results.processed++;

          progressBar.increment(`[${storageType}] ${label}`);
        } catch (error: any) {
          const message = `Failed to process video ${video._id}: ${error.message || error}`;
          logger.error(message, error);
          results.errors.push(message);
          results.processed++;
          progressBar.increment('error');
        }
      }

      if (i + batchSize < videos.length) {
        await sleep(1000);
      }
    }

    progressBar.complete('Account nuke finished');
    console.log('');

    const processedStorage = formatBytes(results.totalStorageBytes);

    logger.info('=== NUKE ACCOUNT COMPLETED ===');
    logger.info(`Account: ${username}`);
    logger.info(`Videos processed: ${results.processed}`);
    logger.info(`Batches: ${results.batches}`);
    logger.info(`S3 objects deleted: ${results.s3ObjectsDeleted}`);
    logger.info(`IPFS hashes unpinned: ${results.ipfsHashesUnpinned}`);
    logger.info(`Database records updated: ${results.dbUpdated}`);
    logger.info(`Targeted storage: ${processedStorage.gb} GB (${processedStorage.tb} TB)`);
    logger.info(`Duplicate storage references skipped: ${results.skippedDuplicates}`);
    logger.info(`Errors: ${results.errors.length}`);

    if (results.errors.length > 0) {
      logger.error('Errors encountered during nuke:');
      results.errors.forEach(err => logger.error(`  - ${err}`));
    }
  } catch (error) {
    logger.error('Nuke account command failed', error);
    throw error;
  } finally {
    await db.disconnect();
  }
}
