import { BrowserWindow, screen } from 'electron';
import { join } from 'node:path';
import type { AppConfig } from '../shared/types';
import { WIDGET_SIZES } from '../shared/types';

export class WidgetWindow {
  private window: BrowserWindow | null = null;

  create(config: AppConfig): BrowserWindow {
    if (this.window && !this.window.isDestroyed()) {
      this.applyConfig(config);
      return this.window;
    }

    const { width, height } = WIDGET_SIZES[config.aspectRatio];

    this.window = new BrowserWindow({
      width,
      height,
      show: false,
      frame: false,
      transparent: true,
      resizable: false,
      movable: false,
      minimizable: false,
      maximizable: false,
      fullscreenable: false,
      alwaysOnTop: true,
      focusable: true,
      hasShadow: true,
      skipTaskbar: true,
      type: 'panel',
      webPreferences: {
        preload: join(__dirname, '../preload/index.js'),
        contextIsolation: true,
        nodeIntegration: false,
        sandbox: false,
      },
    });

    this.window.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
    this.positionWindow(config);

    if (process.env.ELECTRON_RENDERER_URL) {
      void this.window.loadURL(process.env.ELECTRON_RENDERER_URL);
    } else {
      void this.window.loadFile(join(__dirname, '../renderer/index.html'));
    }

    this.window.once('ready-to-show', () => {
      this.window?.showInactive();
    });

    return this.window;
  }

  applyConfig(config: AppConfig): void {
    if (!this.window || this.window.isDestroyed()) {
      return;
    }

    const { width, height } = WIDGET_SIZES[config.aspectRatio];
    this.window.setSize(width, height, false);
    this.positionWindow(config);
  }

  getWindow(): BrowserWindow | null {
    if (this.window?.isDestroyed()) {
      return null;
    }

    return this.window;
  }

  private positionWindow(config: AppConfig): void {
    if (!this.window) {
      return;
    }

    const display = screen.getPrimaryDisplay();
    const workArea = display.workArea;
    const { width, height } = WIDGET_SIZES[config.aspectRatio];
    const x = workArea.x + config.leftPadding;
    const y = workArea.y + Math.round((workArea.height - height) / 2);

    this.window.setBounds({ x, y, width, height }, false);
  }
}
