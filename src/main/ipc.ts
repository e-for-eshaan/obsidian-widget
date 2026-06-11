import { app, dialog, ipcMain, shell } from 'electron';
import { IPC_CHANNELS } from '../shared/types';
import type { SettingsUpdate } from '../shared/types';
import {
  getWidgetSettings,
  loadConfig,
  setAspectRatio,
  setVaultFolder,
  updateConfig,
} from './config';
import { listMarkdownFiles } from './obsidianScanner';
import { resolveWikiLinkTarget } from './relatedNotes';
import type { RefreshScheduler } from './scheduler';
import type { WidgetWindow } from './widgetWindow';

type SettingsListener = () => void;

export async function showVaultFolderPicker(widgetWindow: WidgetWindow): Promise<string | null> {
  const config = loadConfig();
  const parentWindow = widgetWindow.getWindow();

  app.focus({ steal: true });
  if (parentWindow) {
    parentWindow.setAlwaysOnTop(false);
    parentWindow.show();
    parentWindow.focus();
  }

  try {
    const result = await dialog.showOpenDialog(parentWindow ?? undefined, {
      properties: ['openDirectory'],
      defaultPath: config.vaultFolderPath || app.getPath('documents'),
    });

    if (result.canceled || result.filePaths.length === 0) {
      return null;
    }

    return result.filePaths[0] ?? null;
  } finally {
    if (parentWindow) {
      parentWindow.setAlwaysOnTop(true, 'floating');
    }
  }
}

export function broadcastSettings(widgetWindow: WidgetWindow): void {
  const settings = getWidgetSettings(loadConfig());
  const window = widgetWindow.getWindow();
  window?.webContents.send(IPC_CHANNELS.SETTINGS_UPDATED, settings);
}

export function registerIpcHandlers(
  scheduler: RefreshScheduler,
  widgetWindow: WidgetWindow,
  onSettingsChanged: SettingsListener,
): void {
  const notifySettingsChanged = () => {
    broadcastSettings(widgetWindow);
    onSettingsChanged();
  };

  ipcMain.handle(IPC_CHANNELS.GET_NOTE, () => scheduler.getCurrentNote());

  ipcMain.handle(IPC_CHANNELS.GET_SETTINGS, () => getWidgetSettings(loadConfig()));

  ipcMain.handle(IPC_CHANNELS.LIST_SUBFOLDERS, () => {
    const config = loadConfig();
    return getWidgetSettings(config).availableSubfolders;
  });

  ipcMain.handle(IPC_CHANNELS.CHOOSE_FOLDER, async () => {
    const selectedPath = await showVaultFolderPicker(widgetWindow);

    if (!selectedPath) {
      return getWidgetSettings(loadConfig());
    }

    setVaultFolder(selectedPath);
    widgetWindow.applyConfig(loadConfig());
    notifySettingsChanged();
    await scheduler.refreshNow();
    return getWidgetSettings(loadConfig());
  });

  ipcMain.handle(IPC_CHANNELS.UPDATE_SETTINGS, async (_event, update: SettingsUpdate) => {
    const current = loadConfig();
    const next = updateConfig({
      ...update,
      lastPickAt: update.includedSubfolders !== undefined ? null : current.lastPickAt,
      currentFilePath: update.includedSubfolders !== undefined ? null : current.currentFilePath,
    });

    if (update.aspectRatio && update.aspectRatio !== current.aspectRatio) {
      widgetWindow.applyConfig(next);
    }

    notifySettingsChanged();

    if (update.includedSubfolders !== undefined) {
      await scheduler.refreshNow();
    }

    return getWidgetSettings(next);
  });

  ipcMain.handle(IPC_CHANNELS.REFRESH_NOW, async () => {
    await scheduler.refreshNow();
    return scheduler.getCurrentNote();
  });

  ipcMain.handle(IPC_CHANNELS.FORCE_REFRESH, async () => {
    await scheduler.forceRefreshNow();
    return scheduler.getCurrentNote();
  });

  ipcMain.handle(IPC_CHANNELS.REGENERATE_SUMMARY, async () => {
    await scheduler.regenerateSummary();
    return scheduler.getCurrentNote();
  });

  ipcMain.handle(IPC_CHANNELS.LOAD_NOTE, async (_event, filePath: string) => {
    await scheduler.loadNote(filePath);
    return scheduler.getCurrentNote();
  });

  ipcMain.handle(IPC_CHANNELS.OPEN_NOTE, async (_event, filePath: string) => {
    if (!filePath) {
      return false;
    }

    const obsidianUrl = `obsidian://open?path=${encodeURIComponent(filePath)}`;

    try {
      await shell.openExternal(obsidianUrl);
      return true;
    } catch {
      const result = await shell.openPath(filePath);
      return result === '';
    }
  });

  ipcMain.handle(IPC_CHANNELS.OPEN_EXTERNAL, async (_event, url: string) => {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return false;
    }

    await shell.openExternal(url);
    return true;
  });

  ipcMain.handle(IPC_CHANNELS.RESOLVE_WIKI_LINK, async (_event, wikiTarget: string) => {
    const config = loadConfig();
    const vaultFiles = listMarkdownFiles(config.vaultFolderPath, {
      includedSubfolders: config.includedSubfolders,
    });
    return resolveWikiLinkTarget(config.vaultFolderPath, wikiTarget, vaultFiles);
  });

  scheduler.subscribe((note) => {
    const window = widgetWindow.getWindow();
    window?.webContents.send(IPC_CHANNELS.NOTE_UPDATED, note);
  });
}

export function applyAspectRatioFromTray(
  aspectRatio: Parameters<typeof setAspectRatio>[0],
  widgetWindow: WidgetWindow,
): void {
  setAspectRatio(aspectRatio);
  widgetWindow.applyConfig(loadConfig());
  broadcastSettings(widgetWindow);
}
