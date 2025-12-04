#!/usr/bin/env node
import { validateConfig } from './config';
import { logger } from './utils/logger';
import { startWebServer } from './web/server';

async function main() {
  try {
    validateConfig();
    logger.info('Starting 3Speak Storage Admin Web Interface...');
    startWebServer();
  } catch (error) {
    logger.error('Failed to start web server', error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}
