/**
 * Simple progress spinner for long-running operations
 */

export class ProgressSpinner {
  private frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
  private interval: NodeJS.Timeout | null = null;
  private currentFrame = 0;
  private message: string;
  private isSpinning = false;

  constructor(message: string = 'Processing') {
    this.message = message;
  }

  start(): void {
    if (this.isSpinning) return;
    
    this.isSpinning = true;
    this.currentFrame = 0;
    
    // Hide cursor
    process.stdout.write('\x1B[?25l');
    
    this.interval = setInterval(() => {
      process.stdout.write(`\r${this.frames[this.currentFrame]} ${this.message}...`);
      this.currentFrame = (this.currentFrame + 1) % this.frames.length;
    }, 80);
  }

  update(message: string): void {
    this.message = message;
  }

  stop(finalMessage?: string): void {
    if (!this.isSpinning) return;
    
    if (this.interval) {
      clearInterval(this.interval);
      this.interval = null;
    }
    
    this.isSpinning = false;
    
    // Clear the line and show cursor
    process.stdout.write('\r\x1B[K');
    if (finalMessage) {
      console.log(finalMessage);
    }
    process.stdout.write('\x1B[?25h');
  }

  succeed(message: string): void {
    this.stop(`✅ ${message}`);
  }

  fail(message: string): void {
    this.stop(`❌ ${message}`);
  }

  info(message: string): void {
    this.stop(`ℹ️  ${message}`);
  }
}

/**
 * Progress bar for batch operations
 */
export class ProgressBar {
  private total: number;
  private current = 0;
  private width = 40;
  private message: string;

  constructor(total: number, message: string = 'Progress') {
    this.total = total;
    this.message = message;
  }

  update(current: number, statusMessage?: string): void {
    this.current = current;
    const percentage = Math.min(100, Math.floor((current / this.total) * 100));
    const filledWidth = Math.floor((current / this.total) * this.width);
    const emptyWidth = this.width - filledWidth;
    
    const filled = '█'.repeat(filledWidth);
    const empty = '░'.repeat(emptyWidth);
    
    const msg = statusMessage || this.message;
    process.stdout.write(`\r[${filled}${empty}] ${percentage}% (${current}/${this.total}) ${msg}`);
    
    if (current >= this.total) {
      process.stdout.write('\n');
    }
  }

  increment(statusMessage?: string): void {
    this.update(this.current + 1, statusMessage);
  }

  complete(message?: string): void {
    this.update(this.total, message || 'Complete');
  }
}
