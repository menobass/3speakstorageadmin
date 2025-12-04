import { ProgressManager } from './progress-manager';
import { logger } from './logger';

/**
 * Enhanced logging that works for both CLI and web interface
 */
export class UnifiedLogger {
  private progressManager?: ProgressManager;
  private operationId?: string;
  private currentProgress?: {
    totalItems: number;
    processedItems: number;
    currentBatch: number;
    totalBatches: number;
    errors: string[];
  };

  constructor(progressManager?: ProgressManager, operationId?: string) {
    this.progressManager = progressManager;
    this.operationId = operationId;
  }

  /**
   * Initialize progress tracking
   */
  initProgress(totalItems: number, batchSize: number): void {
    if (this.progressManager && this.operationId) {
      this.currentProgress = {
        totalItems,
        processedItems: 0,
        currentBatch: 0,
        totalBatches: Math.ceil(totalItems / batchSize),
        errors: []
      };
      
      this.progressManager.updateProgress(this.operationId, {
        operation: 'Processing',
        totalItems,
        processedItems: 0,
        currentBatch: 0,
        totalBatches: Math.ceil(totalItems / batchSize),
        errors: [],
        status: 'running',
        startTime: new Date(),
        lastUpdate: new Date()
      });
    }
  }

  /**
   * Update progress after processing items
   */
  updateProgress(processedItems: number, currentBatch?: number): void {
    if (this.progressManager && this.operationId && this.currentProgress) {
      this.currentProgress.processedItems = processedItems;
      if (currentBatch !== undefined) {
        this.currentProgress.currentBatch = currentBatch;
      }
      
      this.progressManager.updateProgress(this.operationId, {
        operation: 'Processing',
        totalItems: this.currentProgress.totalItems,
        processedItems: this.currentProgress.processedItems,
        currentBatch: this.currentProgress.currentBatch,
        totalBatches: this.currentProgress.totalBatches,
        errors: this.currentProgress.errors,
        status: 'running',
        startTime: new Date(Date.now() - 60000), // Fake start time
        lastUpdate: new Date()
      });
    }
  }

  /**
   * Add an error to progress tracking
   */
  addError(error: string): void {
    if (this.currentProgress) {
      this.currentProgress.errors.push(error);
    }
  }

  info(message: string): void {
    logger.info(message);
    if (this.progressManager && this.operationId) {
      this.progressManager.logMessage(this.operationId, 'info', message);
    }
  }

  warn(message: string): void {
    logger.warn(message);
    if (this.progressManager && this.operationId) {
      this.progressManager.logMessage(this.operationId, 'warn', message);
    }
  }

  error(message: string): void {
    logger.error(message);
    this.addError(message);
    if (this.progressManager && this.operationId) {
      this.progressManager.logMessage(this.operationId, 'error', message);
    }
  }

  /**
   * Log a preview header with enhanced formatting
   */
  previewHeader(operationType: string): void {
    this.info(`🔍 === PREVIEW MODE: ${operationType.toUpperCase()} ===`);
    this.info(`📋 No changes will be made - this is a preview only`);
  }

  /**
   * Log preview completion message
   */
  previewComplete(): void {
    this.info(`✨ Preview complete - click Execute to perform the actual operation`);
  }

  /**
   * Log video details with creation date for peace of mind
   */
  logVideoPreview(video: any, index: number, total: number, additionalInfo?: string): void {
    const createdDate = video.created ? new Date(video.created).toLocaleDateString() : 'Unknown';
    const daysSinceCreated = video.created ? Math.floor((Date.now() - new Date(video.created).getTime()) / (1000 * 60 * 60 * 24)) : 'Unknown';
    const sizeInfo = video.size ? `📦 ${((video.size) / (1024 * 1024)).toFixed(1)} MB` : '';
    
    this.info(`📹 [${index + 1}/${total}] ${video.title || video._id || 'Untitled'}`);
    this.info(`   👤 Owner: ${video.owner} | 📅 Created: ${createdDate} (${daysSinceCreated} days ago)`);
    this.info(`   📊 Status: ${video.status} | ${sizeInfo}${additionalInfo ? ` | ${additionalInfo}` : ''}`);
    this.info(`   ────────────────────────────────────────`);
  }

  /**
   * Log batch age information
   */
  logBatchAges(batch: any[], batchIndex: number): void {
    const batchAges = batch.map(v => v.created ? Math.floor((Date.now() - new Date(v.created).getTime()) / (1000 * 60 * 60 * 24)) : 0).filter(age => age > 0);
    const minAge = batchAges.length ? Math.min(...batchAges) : 0;
    const maxAge = batchAges.length ? Math.max(...batchAges) : 0;
    
    this.info(`📦 Processing batch ${batchIndex + 1} (${batch.length} videos) - Ages: ${minAge}-${maxAge} days old`);
  }

  /**
   * Log preview summary with storage breakdown
   */
  logPreviewSummary(summary: {
    totalVideos: number;
    totalSizeGB: number;
    storageBreakdown?: { [key: string]: number };
    ageInfo?: { oldest: number; newest: number };
    additionalInfo?: string[];
  }): void {
    this.info(`📋 === PREVIEW SUMMARY ===`);
    this.info(`📼 Total videos: ${summary.totalVideos}`);
    this.info(`💾 Total storage: ${summary.totalSizeGB.toFixed(2)} GB (${(summary.totalSizeGB / 1024).toFixed(3)} TB)`);
    
    if (summary.storageBreakdown) {
      this.info(`🗂️ Storage breakdown:`);
      Object.entries(summary.storageBreakdown).forEach(([type, count]) => {
        if (count > 0) {
          this.info(`   - ${type.toUpperCase()}: ${count} videos`);
        }
      });
    }
    
    if (summary.ageInfo) {
      this.info(`📅 Age range: ${summary.ageInfo.newest} to ${summary.ageInfo.oldest} days old`);
    }
    
    if (summary.additionalInfo) {
      summary.additionalInfo.forEach(info => this.info(`💡 ${info}`));
    }
    
    this.previewComplete();
  }
}