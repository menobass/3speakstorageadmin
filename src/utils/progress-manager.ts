import { Response } from 'express';
import { BatchProgress } from './batch-processor';
import { logger } from './logger';

export interface ProgressClient {
  id: string;
  response: Response;
  lastPing: Date;
}

export class ProgressManager {
  private static instance: ProgressManager;
  private clients: Map<string, ProgressClient> = new Map();
  private operations: Map<string, BatchProgress> = new Map();
  private pingInterval: NodeJS.Timeout;

  private constructor() {
    // Ping clients every 30 seconds to keep connection alive
    this.pingInterval = setInterval(() => {
      this.pingAllClients();
    }, 30000);
  }

  static getInstance(): ProgressManager {
    if (!ProgressManager.instance) {
      ProgressManager.instance = new ProgressManager();
    }
    return ProgressManager.instance;
  }

  addClient(clientId: string, response: Response): void {
    // Set up SSE headers
    response.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Cache-Control'
    });

    const client: ProgressClient = {
      id: clientId,
      response,
      lastPing: new Date()
    };

    this.clients.set(clientId, client);

    // Send initial connection message
    this.sendToClient(clientId, {
      type: 'connected',
      data: { message: 'Connected to progress stream', timestamp: new Date() }
    });

    // Send current operations status
    this.operations.forEach((progress, operationId) => {
      this.sendToClient(clientId, {
        type: 'progress',
        data: { operationId, progress }
      });
    });

    // Handle client disconnect
    response.on('close', () => {
      this.removeClient(clientId);
    });

    logger.info(`Progress client connected: ${clientId}`);
  }

  removeClient(clientId: string): void {
    const client = this.clients.get(clientId);
    if (client) {
      try {
        client.response.end();
      } catch (error) {
        // Ignore errors when ending response
      }
      this.clients.delete(clientId);
      logger.info(`Progress client disconnected: ${clientId}`);
    }
  }

  startOperation(operationId: string, operationName: string): void {
    const progress: BatchProgress = {
      operation: operationName,
      totalItems: 0,
      processedItems: 0,
      currentBatch: 0,
      totalBatches: 0,
      errors: [],
      status: 'running',
      startTime: new Date(),
      lastUpdate: new Date()
    };

    this.operations.set(operationId, progress);
    
    this.broadcastToAllClients({
      type: 'operation_started',
      data: { operationId, progress }
    });

    logger.info(`Operation started: ${operationId} - ${operationName}`);
  }

  updateProgress(operationId: string, progress: BatchProgress): void {
    this.operations.set(operationId, progress);
    
    this.broadcastToAllClients({
      type: 'progress',
      data: { operationId, progress }
    });
  }

  completeOperation(operationId: string): void {
    const progress = this.operations.get(operationId);
    if (progress) {
      progress.status = 'completed';
      progress.lastUpdate = new Date();
      
      this.broadcastToAllClients({
        type: 'operation_completed',
        data: { operationId, progress }
      });

      // Keep completed operations for 5 minutes for clients to see results
      setTimeout(() => {
        this.operations.delete(operationId);
        this.broadcastToAllClients({
          type: 'operation_removed',
          data: { operationId }
        });
      }, 5 * 60 * 1000);

      logger.info(`Operation completed: ${operationId}`);
    }
  }

  errorOperation(operationId: string, error: string): void {
    const progress = this.operations.get(operationId);
    if (progress) {
      progress.status = 'error';
      progress.errors.push(error);
      progress.lastUpdate = new Date();
      
      this.broadcastToAllClients({
        type: 'operation_error',
        data: { operationId, progress, error }
      });

      logger.error(`Operation error: ${operationId} - ${error}`);
    }
  }

  logMessage(operationId: string, level: 'info' | 'warn' | 'error', message: string): void {
    this.broadcastToAllClients({
      type: 'log',
      data: { 
        operationId, 
        level, 
        message, 
        timestamp: new Date() 
      }
    });
  }

  private sendToClient(clientId: string, message: any): void {
    const client = this.clients.get(clientId);
    if (client) {
      try {
        const data = `data: ${JSON.stringify(message)}\n\n`;
        client.response.write(data);
        client.lastPing = new Date();
      } catch (error: any) {
        logger.warn(`Failed to send to client ${clientId}: ${error.message}`);
        this.removeClient(clientId);
      }
    }
  }

  private broadcastToAllClients(message: any): void {
    this.clients.forEach((client, clientId) => {
      this.sendToClient(clientId, message);
    });
  }

  private pingAllClients(): void {
    this.clients.forEach((client, clientId) => {
      this.sendToClient(clientId, {
        type: 'ping',
        data: { timestamp: new Date() }
      });
    });

    // Remove stale clients (no ping for 2 minutes)
    const staleThreshold = new Date(Date.now() - 2 * 60 * 1000);
    this.clients.forEach((client, clientId) => {
      if (client.lastPing < staleThreshold) {
        logger.warn(`Removing stale client: ${clientId}`);
        this.removeClient(clientId);
      }
    });
  }

  getActiveOperations(): { [operationId: string]: BatchProgress } {
    const result: { [operationId: string]: BatchProgress } = {};
    this.operations.forEach((progress, operationId) => {
      result[operationId] = progress;
    });
    return result;
  }

  pauseOperation(operationId: string): void {
    // This would be implemented by the operation processor
    this.broadcastToAllClients({
      type: 'operation_pause_requested',
      data: { operationId }
    });
  }

  resumeOperation(operationId: string): void {
    // This would be implemented by the operation processor
    this.broadcastToAllClients({
      type: 'operation_resume_requested',
      data: { operationId }
    });
  }

  cancelOperation(operationId: string): void {
    // This would be implemented by the operation processor
    this.broadcastToAllClients({
      type: 'operation_cancel_requested',
      data: { operationId }
    });
  }

  cleanup(): void {
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
    }
    
    this.clients.forEach((client, clientId) => {
      this.removeClient(clientId);
    });
  }
}