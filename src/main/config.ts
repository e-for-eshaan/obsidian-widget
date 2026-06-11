import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { app } from 'electron';
import type { AppConfig, AspectRatio, ContentView, WidgetSettings } from '../shared/types';
import {
  DEFAULT_FONT_SIZE_PX,
  DEFAULT_VAULT_PATH,
  MAX_FONT_SIZE_PX,
  MIN_FONT_SIZE_PX,
} from '../shared/types';
import { listSubfolders } from './obsidianScanner';

const DEFAULT_CONFIG: AppConfig = {
  vaultFolderPath: DEFAULT_VAULT_PATH,
  includedSubfolders: [],
  refreshIntervalHours: 4,
  aspectRatio: 'rectangle',
  contentView: 'summary',
  fontSizePx: DEFAULT_FONT_SIZE_PX,
  leftPadding: 16,
  claudeBinary: 'claude',
  summaryCacheDir: '.cache/summaries',
  lastPickAt: null,
  currentFilePath: null,
};

function getConfigPath(): string {
  return join(app.getPath('userData'), 'config.json');
}

function expandPath(inputPath: string): string {
  if (!inputPath) {
    return '';
  }

  if (inputPath.startsWith('~/')) {
    return join(homedir(), inputPath.slice(2));
  }

  return inputPath;
}

function normalizeContentView(value: ContentView | undefined): ContentView {
  return value === 'original' ? 'original' : 'summary';
}

function normalizeFontSizePx(value: number | undefined): number {
  if (!value) {
    return DEFAULT_FONT_SIZE_PX;
  }

  return Math.min(MAX_FONT_SIZE_PX, Math.max(MIN_FONT_SIZE_PX, Math.round(value)));
}

export function loadConfig(): AppConfig {
  const configPath = getConfigPath();

  if (!existsSync(configPath)) {
    saveConfig(DEFAULT_CONFIG);
    return { ...DEFAULT_CONFIG };
  }

  const parsed = JSON.parse(readFileSync(configPath, 'utf8')) as Partial<AppConfig>;
  return {
    ...DEFAULT_CONFIG,
    ...parsed,
    vaultFolderPath: expandPath(parsed.vaultFolderPath ?? DEFAULT_VAULT_PATH),
    includedSubfolders: parsed.includedSubfolders ?? [],
    contentView: normalizeContentView(parsed.contentView),
    fontSizePx: normalizeFontSizePx(parsed.fontSizePx),
    summaryCacheDir: expandPath(parsed.summaryCacheDir ?? DEFAULT_CONFIG.summaryCacheDir),
  };
}

export function saveConfig(config: AppConfig): void {
  const configPath = getConfigPath();
  mkdirSync(app.getPath('userData'), { recursive: true });
  writeFileSync(configPath, JSON.stringify(config, null, 2));
}

export function updateConfig(partial: Partial<AppConfig>): AppConfig {
  const current = loadConfig();
  const next = { ...current, ...partial };

  if (partial.vaultFolderPath !== undefined) {
    next.vaultFolderPath = expandPath(partial.vaultFolderPath);
  }

  if (partial.summaryCacheDir !== undefined) {
    next.summaryCacheDir = expandPath(partial.summaryCacheDir);
  }

  if (partial.contentView !== undefined) {
    next.contentView = normalizeContentView(partial.contentView);
  }

  if (partial.fontSizePx !== undefined) {
    next.fontSizePx = normalizeFontSizePx(partial.fontSizePx);
  }

  saveConfig(next);
  return next;
}

export function setAspectRatio(aspectRatio: AspectRatio): AppConfig {
  return updateConfig({ aspectRatio });
}

export function setVaultFolder(vaultFolderPath: string): AppConfig {
  return updateConfig({
    vaultFolderPath,
    includedSubfolders: [],
    lastPickAt: null,
    currentFilePath: null,
  });
}

export function getRefreshIntervalMs(config: AppConfig): number {
  return config.refreshIntervalHours * 60 * 60 * 1000;
}

export function getSummaryCacheDir(config: AppConfig): string {
  const cacheDir = config.summaryCacheDir.startsWith('.')
    ? join(app.getPath('userData'), config.summaryCacheDir)
    : config.summaryCacheDir;

  mkdirSync(cacheDir, { recursive: true });
  return cacheDir;
}

export function getWidgetSettings(config: AppConfig): WidgetSettings {
  const availableSubfolders = config.vaultFolderPath && existsSync(config.vaultFolderPath)
    ? listSubfolders(config.vaultFolderPath)
    : [];

  return {
    vaultFolderPath: config.vaultFolderPath,
    includedSubfolders: config.includedSubfolders,
    refreshIntervalHours: config.refreshIntervalHours,
    aspectRatio: config.aspectRatio,
    contentView: config.contentView,
    fontSizePx: config.fontSizePx,
    availableSubfolders,
  };
}
