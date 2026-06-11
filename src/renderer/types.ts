import type { NotePayload, SettingsUpdate, WidgetSettings } from '../shared/types';

export interface WidgetApi {
  getNote: () => Promise<NotePayload | null>;
  getSettings: () => Promise<WidgetSettings>;
  updateSettings: (update: SettingsUpdate) => Promise<WidgetSettings>;
  chooseFolder: () => Promise<WidgetSettings>;
  refreshNow: () => Promise<NotePayload | null>;
  forceRefresh: () => Promise<NotePayload | null>;
  regenerateSummary: () => Promise<NotePayload | null>;
  loadNote: (filePath: string) => Promise<NotePayload | null>;
  openNote: (filePath: string) => Promise<boolean>;
  openExternal: (url: string) => Promise<boolean>;
  resolveWikiLink: (wikiTarget: string) => Promise<string | null>;
  onNoteUpdated: (callback: (note: NotePayload) => void) => () => void;
  onSettingsUpdated: (callback: (settings: WidgetSettings) => void) => () => void;
}

declare global {
  interface Window {
    widgetApi: WidgetApi;
  }
}

export {};
