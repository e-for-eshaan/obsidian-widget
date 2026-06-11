import type { NotePayload, WidgetStatus } from './types';

export const APP_GROUP_SUFFIX = 'com.obsidianwidget.shared';
export const LEGACY_APP_GROUP_ID = 'group.com.obsidianwidget.shared';
export const APP_GROUP_ID = LEGACY_APP_GROUP_ID;
export const WIDGET_STATE_FILENAME = 'widget-state.json';

export interface WidgetSharedState {
  version: 1;
  updatedAt: string;
  status: WidgetStatus;
  title: string;
  summary: string;
  filePath: string;
  parentFolder: string;
  nextRefreshAt: string;
  errorMessage?: string;
}

export function notePayloadToWidgetState(note: NotePayload): WidgetSharedState {
  return {
    version: 1,
    updatedAt: new Date().toISOString(),
    status: note.status,
    title: note.title,
    summary: note.summary,
    filePath: note.filePath,
    parentFolder: note.parentFolder,
    nextRefreshAt: note.nextRefreshAt,
    errorMessage: note.errorMessage,
  };
}
