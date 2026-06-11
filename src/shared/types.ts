export type AspectRatio = 'square' | 'rectangle';

export type ContentView = 'summary' | 'original';

export type WidgetStatus = 'loading' | 'ready' | 'error' | 'needsSetup';

export const DEFAULT_FONT_SIZE_PX = 11;
export const MIN_FONT_SIZE_PX = 9;
export const MAX_FONT_SIZE_PX = 16;

export interface AppConfig {
  vaultFolderPath: string;
  includedSubfolders: string[];
  refreshIntervalHours: number;
  aspectRatio: AspectRatio;
  contentView: ContentView;
  fontSizePx: number;
  leftPadding: number;
  claudeBinary: string;
  summaryCacheDir: string;
  lastPickAt: string | null;
  currentFilePath: string | null;
}

export interface WidgetSettings {
  vaultFolderPath: string;
  includedSubfolders: string[];
  refreshIntervalHours: number;
  aspectRatio: AspectRatio;
  contentView: ContentView;
  fontSizePx: number;
  availableSubfolders: string[];
}

export interface RelatedNote {
  title: string;
  filePath: string;
}

export interface NotePayload {
  title: string;
  summary: string;
  content: string;
  relativePath: string;
  filePath: string;
  parentFolder: string;
  relatedNotes: RelatedNote[];
  nextRefreshAt: string;
  status: WidgetStatus;
  errorMessage?: string;
}

export interface WidgetDimensions {
  width: number;
  height: number;
}

export const DEFAULT_VAULT_PATH =
  '/Users/eshaanyadav/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mind';

export const WIDGET_SIZES: Record<AspectRatio, WidgetDimensions> = {
  square: { width: 320, height: 460 },
  rectangle: { width: 320, height: 640 },
};

export const IPC_CHANNELS = {
  GET_NOTE: 'widget:get-note',
  GET_SETTINGS: 'widget:get-settings',
  UPDATE_SETTINGS: 'widget:update-settings',
  CHOOSE_FOLDER: 'widget:choose-folder',
  LIST_SUBFOLDERS: 'widget:list-subfolders',
  NOTE_UPDATED: 'widget:note-updated',
  SETTINGS_UPDATED: 'widget:settings-updated',
  REFRESH_NOW: 'widget:refresh-now',
  FORCE_REFRESH: 'widget:force-refresh',
  REGENERATE_SUMMARY: 'widget:regenerate-summary',
  LOAD_NOTE: 'widget:load-note',
  OPEN_NOTE: 'widget:open-note',
  OPEN_EXTERNAL: 'widget:open-external',
  RESOLVE_WIKI_LINK: 'widget:resolve-wiki-link',
} as const;

export type SettingsUpdate = Partial<
  Pick<
    AppConfig,
    'includedSubfolders' | 'refreshIntervalHours' | 'aspectRatio' | 'contentView' | 'fontSizePx'
  >
>;
