import { logger } from './logger';

export interface BatchProgress {
  operation: string;
  totalItems: number;
  processedItems: number;
  currentBatch: number;
  totalBatches: number;
  errors: string[];
  status: 'running' | 'paused' | 'completed' | 'error' | 'cancelled';
  startTime: Date;
  lastUpdate: Date;
}

export interface BatchProcessorOptions {
  batchSize: number;
  delayBetweenBatches: number; // milliseconds
  maxRetries?: number;
  onProgress?: (progress: BatchProgress) => void;
}

export class BatchProcessor<T> {
  private progress: BatchProgress;
  private options: BatchProcessorOptions;
  private isPaused = false;
  private isCancelled = false;

  constructor(
    operation: string,
    items: T[],
    options: BatchProcessorOptions
  ) {
    this.options = {
      maxRetries: 3,
      ...options
    };

    this.progress = {
      operation,
      totalItems: items.length,
      processedItems: 0,
      currentBatch: 0,
      totalBatches: Math.ceil(items.length / options.batchSize),
      errors: [],
      status: 'running',
      startTime: new Date(),
      lastUpdate: new Date()
    };
  }

  async processBatches<R>(
    items: T[],
    processor: (batch: T[], batchIndex: number) => Promise<R[]>
  ): Promise<R[]> {
    const results: R[] = [];
    const { batchSize, delayBetweenBatches } = this.options;

    logger.info(`Starting batch processing: ${this.progress.operation}`);
    logger.info(`Total items: ${items.length}, Batch size: ${batchSize}, Total batches: ${this.progress.totalBatches}`);

    for (let i = 0; i < items.length; i += batchSize) {
      // Check for pause/cancel
      while (this.isPaused && !this.isCancelled) {
        await this.sleep(1000);
      }

      if (this.isCancelled) {
        this.progress.status = 'cancelled';
        logger.warn(`Batch processing cancelled: ${this.progress.operation}`);
        break;
      }

      const batch = items.slice(i, i + batchSize);
      const batchIndex = Math.floor(i / batchSize);
      this.progress.currentBatch = batchIndex + 1;

      logger.info(`Processing batch ${this.progress.currentBatch}/${this.progress.totalBatches} (${batch.length} items)`);

      try {
        const batchResults = await this.processBatchWithRetry(batch, batchIndex, processor);
        results.push(...batchResults);
        
        this.progress.processedItems += batch.length;
        this.progress.lastUpdate = new Date();
        
        this.reportProgress();

        // Add delay between batches to prevent overwhelming the system
        if (i + batchSize < items.length && delayBetweenBatches > 0) {
          logger.info(`Waiting ${delayBetweenBatches}ms before next batch...`);
          await this.sleep(delayBetweenBatches);
        }

      } catch (error: any) {
        const errorMsg = `Batch ${this.progress.currentBatch} failed after retries: ${error.message}`;
        this.progress.errors.push(errorMsg);
        logger.error(errorMsg);
        
        this.reportProgress();
      }
    }

    if (!this.isCancelled) {
      this.progress.status = this.progress.errors.length > 0 ? 'error' : 'completed';
      logger.info(`Batch processing ${this.progress.status}: ${this.progress.operation}`);
      logger.info(`Processed ${this.progress.processedItems}/${this.progress.totalItems} items with ${this.progress.errors.length} errors`);
    }

    this.reportProgress();
    return results;
  }

  private async processBatchWithRetry<R>(
    batch: T[],
    batchIndex: number,
    processor: (batch: T[], batchIndex: number) => Promise<R[]>
  ): Promise<R[]> {
    let lastError: Error | null = null;
    
    for (let retry = 0; retry <= (this.options.maxRetries || 3); retry++) {
      try {
        return await processor(batch, batchIndex);
      } catch (error: any) {
        lastError = error;
        
        if (retry < (this.options.maxRetries || 3)) {
          const delay = Math.pow(2, retry) * 1000; // Exponential backoff
          logger.warn(`Batch ${batchIndex + 1} failed (attempt ${retry + 1}), retrying in ${delay}ms: ${error.message}`);
          await this.sleep(delay);
        }
      }
    }
    
    throw lastError;
  }

  private reportProgress(): void {
    if (this.options.onProgress) {
      this.options.onProgress({ ...this.progress });
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  pause(): void {
    this.isPaused = true;
    this.progress.status = 'paused';
    logger.info(`Batch processing paused: ${this.progress.operation}`);
    this.reportProgress();
  }

  resume(): void {
    this.isPaused = false;
    this.progress.status = 'running';
    logger.info(`Batch processing resumed: ${this.progress.operation}`);
    this.reportProgress();
  }

  cancel(): void {
    this.isCancelled = true;
    this.progress.status = 'cancelled';
    logger.info(`Batch processing cancelled: ${this.progress.operation}`);
    this.reportProgress();
  }

  getProgress(): BatchProgress {
    return { ...this.progress };
  }
}