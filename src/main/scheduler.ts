import { existsSync } from 'node:fs';
import type { AppConfig, NotePayload } from '../shared/types';
import { loadConfig, updateConfig, getRefreshIntervalMs } from './config';
import {
  getParentFolder,
  listMarkdownFiles,
  pickRandomMarkdownFile,
  readMarkdownNote,
} from './obsidianScanner';
import { resolveRelatedNoteTitles } from './relatedNotes';
import { summarizeNote } from './summaryService';

type NoteListener = (note: NotePayload) => void;

interface LoadNoteOptions {
  bypassCache?: boolean;
  updateLastPick?: boolean;
}

export class RefreshScheduler {
  private timer: NodeJS.Timeout | null = null;
  private listeners = new Set<NoteListener>();
  private currentNote: NotePayload | null = null;
  private refreshing = false;

  subscribe(listener: NoteListener): () => void {
    this.listeners.add(listener);
    if (this.currentNote) {
      listener(this.currentNote);
    }

    return () => {
      this.listeners.delete(listener);
    };
  }

  async start(): Promise<void> {
    await this.refresh(false);
    this.scheduleNext();
  }

  async refreshNow(): Promise<void> {
    await this.refresh(true, false);
    this.scheduleNext();
  }

  async forceRefreshNow(): Promise<void> {
    await this.refresh(true, true);
    this.scheduleNext();
  }

  async regenerateSummary(): Promise<void> {
    if (this.refreshing) {
      return;
    }

    const config = loadConfig();
    if (!config.vaultFolderPath || !config.currentFilePath || !existsSync(config.currentFilePath)) {
      return;
    }

    this.refreshing = true;

    try {
      await this.loadNoteAtPath(config.currentFilePath, {
        bypassCache: true,
        updateLastPick: false,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error while regenerating summary';
      this.publishEmptyState('error', {
        title: 'Summary failed',
        summary: message,
        filePath: config.currentFilePath,
        errorMessage: message,
      });
    } finally {
      this.refreshing = false;
    }
  }

  async loadNote(filePath: string): Promise<void> {
    if (this.refreshing) {
      return;
    }

    this.refreshing = true;

    try {
      const config = loadConfig();
      if (!config.vaultFolderPath || !existsSync(filePath)) {
        return;
      }

      await this.loadNoteAtPath(filePath, { bypassCache: false, updateLastPick: false });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error while loading note';
      this.publishEmptyState('error', {
        title: 'Summary failed',
        summary: message,
        filePath,
        errorMessage: message,
      });
    } finally {
      this.refreshing = false;
    }
  }

  stop(): void {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
  }

  getCurrentNote(): NotePayload | null {
    return this.currentNote;
  }

  private scheduleNext(): void {
    this.stop();
    const config = loadConfig();
    const intervalMs = getRefreshIntervalMs(config);
    const lastPickAt = config.lastPickAt ? Date.parse(config.lastPickAt) : Date.now();
    const elapsed = Date.now() - lastPickAt;
    const delay = Math.max(intervalMs - elapsed, 0);

    this.timer = setTimeout(() => {
      void this.refresh(true).then(() => this.scheduleNext());
    }, delay);
  }

  private async refresh(forceNewPick: boolean, bypassCache = false): Promise<void> {
    if (this.refreshing) {
      return;
    }

    this.refreshing = true;
    const config = loadConfig();

    if (!config.vaultFolderPath || !existsSync(config.vaultFolderPath)) {
      this.publishEmptyState('needsSetup', {
        title: 'Obsidian Widget',
        summary: 'Choose an Obsidian folder below or from the menu bar tray.',
      });
      this.refreshing = false;
      return;
    }

    this.publishLoadingState();

    try {
      const scanOptions = { includedSubfolders: config.includedSubfolders };
      const shouldPickNew = forceNewPick || this.isRefreshDue(config);
      const filePath = shouldPickNew
        ? pickRandomMarkdownFile(config.vaultFolderPath, scanOptions, config.currentFilePath)
        : config.currentFilePath ?? pickRandomMarkdownFile(config.vaultFolderPath, scanOptions);

      if (!filePath) {
        this.publishEmptyState('error', {
          title: 'No notes found',
          summary: 'No markdown files were found in the selected folder.',
          errorMessage: 'Vault folder has no readable .md files.',
        });
        this.refreshing = false;
        return;
      }

      await this.loadNoteAtPath(filePath, {
        bypassCache,
        updateLastPick: shouldPickNew || !config.lastPickAt,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error while refreshing note';
      this.publishEmptyState('error', {
        title: 'Summary failed',
        summary: message,
        filePath: config.currentFilePath ?? '',
        errorMessage: message,
      });
    } finally {
      this.refreshing = false;
    }
  }

  private async loadNoteAtPath(filePath: string, options: LoadNoteOptions = {}): Promise<void> {
    const config = loadConfig();
    const bypassCache = options.bypassCache ?? false;
    const updateLastPick = options.updateLastPick ?? false;

    const note = readMarkdownNote(config.vaultFolderPath, filePath);
    this.publishNoteAwaitingSummary(note, config);

    const summaryResult = await summarizeNote(
      config,
      note.title,
      note.content,
      note.filePath,
      { bypassCache },
    );

    const scanOptions = { includedSubfolders: config.includedSubfolders };
    const vaultFiles = listMarkdownFiles(config.vaultFolderPath, scanOptions);
    const relatedNotes = resolveRelatedNoteTitles(
      config.vaultFolderPath,
      summaryResult.relatedNotes.map((item) => item.title),
      vaultFiles,
      note.filePath,
    );

    const nextConfig = updateConfig({
      lastPickAt: updateLastPick ? new Date().toISOString() : config.lastPickAt,
      currentFilePath: filePath,
    });

    this.publish({
      title: note.title,
      summary: summaryResult.summary,
      content: note.content,
      relativePath: note.relativePath,
      filePath: note.filePath,
      parentFolder: getParentFolder(note.relativePath),
      relatedNotes,
      nextRefreshAt: this.getNextRefreshAt(nextConfig).toISOString(),
      status: 'ready',
    });
  }

  private publishLoadingState(): void {
    const config = loadConfig();
    this.publish({
      title: 'Loading note…',
      summary: 'Picking a random note from your vault.',
      content: '',
      relativePath: '',
      filePath: '',
      parentFolder: '',
      relatedNotes: [],
      nextRefreshAt: this.getNextRefreshAt(config).toISOString(),
      status: 'loading',
    });
  }

  private publishNoteAwaitingSummary(
    note: ReturnType<typeof readMarkdownNote>,
    config: AppConfig,
  ): void {
    this.publish({
      title: note.title,
      summary: 'Generating summary…',
      content: note.content,
      relativePath: note.relativePath,
      filePath: note.filePath,
      parentFolder: getParentFolder(note.relativePath),
      relatedNotes: [],
      nextRefreshAt: this.getNextRefreshAt(config).toISOString(),
      status: 'loading',
    });
  }

  private publishEmptyState(
    status: NotePayload['status'],
    partial: Partial<NotePayload> & Pick<NotePayload, 'title' | 'summary'>,
  ): void {
    const config = loadConfig();
    this.publish({
      title: partial.title,
      summary: partial.summary,
      content: '',
      relativePath: '',
      filePath: partial.filePath ?? '',
      parentFolder: '',
      relatedNotes: [],
      nextRefreshAt: this.getNextRefreshAt(config).toISOString(),
      status,
      errorMessage: partial.errorMessage,
    });
  }

  private isRefreshDue(config: AppConfig): boolean {
    if (!config.lastPickAt) {
      return true;
    }

    const elapsed = Date.now() - Date.parse(config.lastPickAt);
    return elapsed >= getRefreshIntervalMs(config);
  }

  private getNextRefreshAt(config: AppConfig): Date {
    const lastPickAt = config.lastPickAt ? Date.parse(config.lastPickAt) : Date.now();
    return new Date(lastPickAt + getRefreshIntervalMs(config));
  }

  private publish(note: NotePayload): void {
    this.currentNote = note;
    for (const listener of this.listeners) {
      listener(note);
    }
  }
}
