export interface ContentCreator {
  _id: string;
  username: string;
  banned: boolean;
  banReason?: string;
  joined: Date;
  livestreamEnabled: boolean;
  canUpload: boolean;
  canProxyUpvote: boolean;
  isCitizenJournalist: boolean;
  limit: number;
  hidden: boolean;
  score: number;
  postWarning: boolean;
  badges: string[];
  verified: boolean;
  upvoteEligible: boolean;
}

export interface Video {
  _id: string;
  owner: string; // Username from contentcreators collection
  title?: string;
  description?: string;
  filename?: string; // S3 filename OR "ipfs://..." for IPFS videos
  views: number;
  created: Date;
  duration?: number;
  size?: number;
  status: 'published' | 'deleted' | 'uploaded' | 'encoding_ipfs' | 'processing' | 'failed' | 'draft';
  // Additional 3speak specific fields
  permlink?: string;
  originalFilename?: string;
  tags?: string;
  tags_v2?: string[];
  category?: string;
  upload_type?: 'ipfs' | 's3';
  encoding?: {
    360: boolean;
    480: boolean;
    720: boolean;
    1080: boolean;
  };
  encodingProgress?: number;
  video_v2?: string; // IPFS manifest URL
  thumbnail?: string;
  job_id?: string;
  local_filename?: string;
}

export interface CleanupCriteria {
  bannedUsers?: boolean;
  ageThresholdDays?: number;
  maxViews?: number;
  minViews?: number;
  orphaned?: boolean;
  status?: string[];
  stuckDays?: number;
  storageType?: 'ipfs' | 's3' | 'unknown';
}

export interface CleanupResult {
  videosFound: number;
  videosProcessed: number;
  ipfsUnpinned: number;
  s3Deleted: number;
  errors: string[];
  dryRun: boolean;
}

export interface StorageConfig {
  mongodb: {
    uri: string;
    dbName: string;
  };
  ipfs: {
    apiUrl: string;
    gatewayUrl: string;
  };
  s3: {
    accessKeyId: string;
    secretAccessKey: string;
    region: string;
    bucketName: string;
    endpoint?: string;
  };
  safety: {
    dryRunMode: boolean;
    requireConfirmation: boolean;
    maxBatchSize: number;
  };
}