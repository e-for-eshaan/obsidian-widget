import { contextBridge, ipcRenderer } from 'electron';
import { IPC_CHANNELS } from '../shared/types';
import type { NotePayload, SettingsUpdate, WidgetSettings } from '../shared/types';

contextBridge.exposeInMainWorld('widgetApi', {
  getNote: (): Promise<NotePayload | null> => ipcRenderer.invoke(IPC_CHANNELS.GET_NOTE),
  getSettings: (): Promise<WidgetSettings> => ipcRenderer.invoke(IPC_CHANNELS.GET_SETTINGS),
  updateSettings: (update: SettingsUpdate): Promise<WidgetSettings> =>
    ipcRenderer.invoke(IPC_CHANNELS.UPDATE_SETTINGS, update),
  chooseFolder: (): Promise<WidgetSettings> => ipcRenderer.invoke(IPC_CHANNELS.CHOOSE_FOLDER),
  refreshNow: (): Promise<NotePayload | null> => ipcRenderer.invoke(IPC_CHANNELS.REFRESH_NOW),
  forceRefresh: (): Promise<NotePayload | null> => ipcRenderer.invoke(IPC_CHANNELS.FORCE_REFRESH),
  regenerateSummary: (): Promise<NotePayload | null> =>
    ipcRenderer.invoke(IPC_CHANNELS.REGENERATE_SUMMARY),
  loadNote: (filePath: string): Promise<NotePayload | null> =>
    ipcRenderer.invoke(IPC_CHANNELS.LOAD_NOTE, filePath),
  openNote: (filePath: string): Promise<boolean> => ipcRenderer.invoke(IPC_CHANNELS.OPEN_NOTE, filePath),
  openExternal: (url: string): Promise<boolean> => ipcRenderer.invoke(IPC_CHANNELS.OPEN_EXTERNAL, url),
  resolveWikiLink: (wikiTarget: string): Promise<string | null> =>
    ipcRenderer.invoke(IPC_CHANNELS.RESOLVE_WIKI_LINK, wikiTarget),
  onNoteUpdated: (callback: (note: NotePayload) => void): (() => void) => {
    const listener = (_event: Electron.IpcRendererEvent, note: NotePayload) => {
      callback(note);
    };

    ipcRenderer.on(IPC_CHANNELS.NOTE_UPDATED, listener);
    return () => {
      ipcRenderer.removeListener(IPC_CHANNELS.NOTE_UPDATED, listener);
    };
  },
  onSettingsUpdated: (callback: (settings: WidgetSettings) => void): (() => void) => {
    const listener = (_event: Electron.IpcRendererEvent, settings: WidgetSettings) => {
      callback(settings);
    };

    ipcRenderer.on(IPC_CHANNELS.SETTINGS_UPDATED, listener);
    return () => {
      ipcRenderer.removeListener(IPC_CHANNELS.SETTINGS_UPDATED, listener);
    };
  },
});
