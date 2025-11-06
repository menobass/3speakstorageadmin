import winston from 'winston';

const logLevel = process.env.LOG_LEVEL || 'info';
const logFile = process.env.LOG_FILE || './logs/app.log';

export const logger = winston.createLogger({
  level: logLevel,
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: '3speak-storage-admin' },
  transports: [
    new winston.transports.File({ filename: logFile }),
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
});

export const createProgressLogger = (operation: string, total: number) => {
  let processed = 0;
  
  return {
    increment: () => {
      processed++;
      const percentage = ((processed / total) * 100).toFixed(1);
      logger.info(`${operation}: ${processed}/${total} (${percentage}%)`);
    },
    complete: () => {
      logger.info(`${operation}: Completed ${processed}/${total}`);
    }
  };
};