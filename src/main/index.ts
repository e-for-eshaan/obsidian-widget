import {
  app,
  Menu,
  nativeImage,
  shell,
  Tray,
} from 'electron';
import { loadConfig, setVaultFolder } from './config';
import { DetailWindow } from './detailWindow';
import { broadcastSettings, registerIpcHandlers, showVaultFolderPicker } from './ipc';
import { RefreshScheduler } from './scheduler';

let tray: Tray | null = null;
const detailWindow = new DetailWindow();
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
      label: 'Open Note Viewer…',
      click: () => {
        detailWindow.show();
      },
    },
    { type: 'separator' },
    {
      label: 'Choose Obsidian Folder…',
      click: async () => {
        const selectedPath = await showVaultFolderPicker(detailWindow);

        if (!selectedPath) {
          return;
        }

        setVaultFolder(selectedPath);
        broadcastSettings(detailWindow);
        await scheduler.refreshNow();
        rebuildTray();
      },
    },
    { type: 'separator' },
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

function createTray(): void {
  tray = new Tray(buildTrayIcon());
  tray.setToolTip('Obsidian Widget');
  tray.setContextMenu(buildTrayMenu());
}

async function bootstrap(): Promise<void> {
  if (process.platform === 'darwin') {
    app.dock.hide();
  }

  detailWindow.create();
  registerIpcHandlers(scheduler, detailWindow, rebuildTray);
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
  const window = detailWindow.getWindow();
  if (window && !window.isDestroyed()) {
    window.removeAllListeners('close');
    window.destroy();
  }
});

process.on('uncaughtException', (error) => {
  console.error('Uncaught exception:', error);
});
