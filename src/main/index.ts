import {
  app,
  Menu,
  nativeImage,
  shell,
  Tray,
} from 'electron';
import type { AspectRatio } from '../shared/types';
import { loadConfig, setVaultFolder } from './config';
import { applyAspectRatioFromTray, broadcastSettings, registerIpcHandlers, showVaultFolderPicker } from './ipc';
import { RefreshScheduler } from './scheduler';
import { WidgetWindow } from './widgetWindow';

let tray: Tray | null = null;
const widgetWindow = new WidgetWindow();
const scheduler = new RefreshScheduler();

function buildTrayIcon(): Electron.NativeImage {
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18">
      <rect x="1" y="1" width="16" height="16" rx="4" fill="#7c6cff"/>
      <path d="M5 5h8v1.5H5V5zm0 3.5h8V10H5V8.5zm0 3.5h5.5V13H5v-1z" fill="#ffffff"/>
    </svg>
  `;

  return nativeImage.createFromDataURL(
    `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`,
  );
}

function buildTrayMenu(): Menu {
  const config = loadConfig();

  return Menu.buildFromTemplate([
    {
      label: 'Choose Obsidian Folder…',
      click: async () => {
        const selectedPath = await showVaultFolderPicker(widgetWindow);

        if (!selectedPath) {
          return;
        }

        const nextConfig = setVaultFolder(selectedPath);
        widgetWindow.applyConfig(nextConfig);
        broadcastSettings(widgetWindow);
        await scheduler.refreshNow();
        rebuildTray();
      },
    },
    { type: 'separator' },
    {
      label: 'Aspect Ratio',
      submenu: [
        {
          label: 'Square',
          type: 'radio',
          checked: config.aspectRatio === 'square',
          click: () => {
            applyAspectRatio('square');
          },
        },
        {
          label: 'Rectangle',
          type: 'radio',
          checked: config.aspectRatio === 'rectangle',
          click: () => {
            applyAspectRatio('rectangle');
          },
        },
      ],
    },
    {
      label: 'Force Refresh',
      click: () => {
        void scheduler.forceRefreshNow();
      },
    },
    {
      label: 'Refresh Now',
      click: () => {
        void scheduler.refreshNow();
      },
    },
    {
      label: 'Open Current Note',
      enabled: Boolean(config.currentFilePath),
      click: () => {
        const note = scheduler.getCurrentNote();
        if (note?.filePath) {
          void shell.openPath(note.filePath);
        }
      },
    },
    { type: 'separator' },
    {
      label: 'Quit',
      click: () => {
        app.quit();
      },
    },
  ]);
}

function rebuildTray(): void {
  if (!tray) {
    return;
  }

  tray.setContextMenu(buildTrayMenu());
}

function applyAspectRatio(aspectRatio: AspectRatio): void {
  applyAspectRatioFromTray(aspectRatio, widgetWindow);
  rebuildTray();
}

function createTray(): void {
  tray = new Tray(buildTrayIcon());
  tray.setToolTip('Obsidian Widget');
  tray.setContextMenu(buildTrayMenu());
}

async function bootstrap(): Promise<void> {
  if (process.platform === 'darwin') {
    app.dock.hide();
  }

  const config = loadConfig();
  widgetWindow.create(config);
  registerIpcHandlers(scheduler, widgetWindow, rebuildTray);
  createTray();
  await scheduler.start();
}

app.whenReady().then(() => {
  void bootstrap();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('before-quit', () => {
  scheduler.stop();
});

process.on('uncaughtException', (error) => {
  console.error('Uncaught exception:', error);
});
