import { basename, relative } from 'node:path';
import type { RelatedNote } from '../shared/types';
import { readMarkdownNote } from './obsidianScanner';

const MAX_RELATED = 8;

interface FileLookup {
  byBasename: Map<string, string>;
  byRelativePath: Map<string, string>;
  byTitle: Map<string, string>;
}

function normalizeKey(value: string): string {
  return value.replace(/\\/g, '/').trim().toLowerCase();
}

function buildFileLookup(vaultFolderPath: string, files: string[]): FileLookup {
  const byBasename = new Map<string, string>();
  const byRelativePath = new Map<string, string>();
  const byTitle = new Map<string, string>();

  for (const filePath of files) {
    const relPath = relative(vaultFolderPath, filePath);
    const basenameKey = normalizeKey(basename(filePath, '.md'));
    const relativeKey = normalizeKey(relPath.replace(/\.md$/i, ''));

    if (!byBasename.has(basenameKey)) {
      byBasename.set(basenameKey, filePath);
    }

    byRelativePath.set(relativeKey, filePath);

    const note = readMarkdownNote(vaultFolderPath, filePath);
    const titleKey = normalizeKey(note.title);
    if (!byTitle.has(titleKey)) {
      byTitle.set(titleKey, filePath);
    }
  }

  return { byBasename, byRelativePath, byTitle };
}

function resolveNoteTarget(target: string, lookup: FileLookup): string | null {
  const normalized = normalizeKey(target);
  const relativeMatch = lookup.byRelativePath.get(normalized);
  if (relativeMatch) {
    return relativeMatch;
  }

  const titleMatch = lookup.byTitle.get(normalized);
  if (titleMatch) {
    return titleMatch;
  }

  const baseSegment = normalized.split('/').pop() ?? normalized;
  return lookup.byBasename.get(baseSegment) ?? null;
}

export function resolveWikiLinkTarget(
  vaultFolderPath: string,
  target: string,
  vaultFiles: string[],
): string | null {
  if (!target.trim() || vaultFiles.length === 0) {
    return null;
  }

  const lookup = buildFileLookup(vaultFolderPath, vaultFiles);
  const fileTarget = target.split('#')[0]?.trim() ?? target.trim();
  return resolveNoteTarget(fileTarget, lookup);
}

export function resolveRelatedNoteTitles(
  vaultFolderPath: string,
  titles: string[],
  vaultFiles: string[],
  excludeFilePath?: string,
): RelatedNote[] {
  if (titles.length === 0 || vaultFiles.length === 0) {
    return [];
  }

  const lookup = buildFileLookup(vaultFolderPath, vaultFiles);
  const relatedByPath = new Map<string, RelatedNote>();

  for (const title of titles) {
    const resolvedPath = resolveNoteTarget(title, lookup);
    if (!resolvedPath || resolvedPath === excludeFilePath || relatedByPath.has(resolvedPath)) {
      continue;
    }

    const note = readMarkdownNote(vaultFolderPath, resolvedPath);
    relatedByPath.set(resolvedPath, {
      title: note.title,
      filePath: note.filePath,
    });

    if (relatedByPath.size >= MAX_RELATED) {
      break;
    }
  }

  return [...relatedByPath.values()];
}
