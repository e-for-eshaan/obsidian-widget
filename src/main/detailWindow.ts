import { BrowserWindow } from 'electron';
import { join } from 'node:path';

const DEFAULT_WIDTH = 480;
const DEFAULT_HEIGHT = 640;

export class DetailWindow {
  private window: BrowserWindow | null = null;

  create(): BrowserWindow {
    if (this.window && !this.window.isDestroyed()) {
      return this.window;
    }

    this.window = new BrowserWindow({
      width: DEFAULT_WIDTH,
      height: DEFAULT_HEIGHT,
      minWidth: 360,
      minHeight: 480,
      show: false,
      title: 'Obsidian Widget',
      webPreferences: {
        preload: join(__dirname, '../preload/index.js'),
        contextIsolation: true,
        nodeIntegration: false,
        sandbox: false,
      },
    });

    this.window.on('close', (event) => {
      if (this.window && !this.window.isDestroyed()) {
        event.preventDefault();
        this.window.hide();
      }
    });

    if (process.env.ELECTRON_RENDERER_URL) {
      void this.window.loadURL(process.env.ELECTRON_RENDERER_URL);
    } else {
      void this.window.loadFile(join(__dirname, '../renderer/index.html'));
    }

    return this.window;
  }

  show(): void {
    if (!this.window || this.window.isDestroyed()) {
      this.create();
    }

    if (!this.window) {
      return;
    }

    if (this.window.webContents.isLoading()) {
      this.window.once('ready-to-show', () => {
        this.window?.show();
        this.window?.focus();
      });
      return;
    }

    this.window.show();
    this.window.focus();
  }

  getWindow(): BrowserWindow | null {
    if (this.window?.isDestroyed()) {
      return null;
    }

    return this.window;
  }
}
