import { createHash, randomInt } from 'node:crypto';
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { basename, join, relative } from 'node:path';

export interface MarkdownNote {
  filePath: string;
  relativePath: string;
  title: string;
  content: string;
  mtimeMs: number;
}

export interface ScanOptions {
  includedSubfolders?: string[];
}

const SKIP_DIRS = new Set(['.obsidian', '.git', '.trash', 'templates', 'node_modules']);

function shouldSkipDir(name: string): boolean {
  return name.startsWith('.') || SKIP_DIRS.has(name);
}

function normalizePath(value: string): string {
  return value.replace(/\\/g, '/').replace(/\/$/, '');
}

function isFileIncluded(relativePath: string, includedSubfolders: string[]): boolean {
  if (includedSubfolders.length === 0) {
    return true;
  }

  const normalizedPath = normalizePath(relativePath);

  return includedSubfolders.some((folder) => {
    const normalizedFolder = normalizePath(folder);

    if (normalizedFolder === '(root)') {
      return !normalizedPath.includes('/');
    }

    return (
      normalizedPath === normalizedFolder
      || normalizedPath.startsWith(`${normalizedFolder}/`)
    );
  });
}

function collectMarkdownFiles(rootDir: string, currentDir = rootDir): string[] {
  const entries = readdirSync(currentDir, { withFileTypes: true });
  const files: string[] = [];

  for (const entry of entries) {
    const fullPath = join(currentDir, entry.name);

    if (entry.isDirectory()) {
      if (!shouldSkipDir(entry.name)) {
        files.push(...collectMarkdownFiles(rootDir, fullPath));
      }
      continue;
    }

    if (entry.isFile() && entry.name.endsWith('.md')) {
      files.push(fullPath);
    }
  }

  return files;
}

function stripFrontmatter(content: string): string {
  if (!content.startsWith('---\n')) {
    return content.trim();
  }

  const closingIndex = content.indexOf('\n---\n', 4);
  if (closingIndex === -1) {
    return content.trim();
  }

  return content.slice(closingIndex + 5).trim();
}

function extractTitle(content: string, filePath: string): string {
  const headingMatch = content.match(/^#\s+(.+)$/m);
  if (headingMatch?.[1]) {
    return headingMatch[1].trim();
  }

  return basename(filePath, '.md');
}

function collectFolderPaths(currentDir: string, relativePrefix: string): string[] {
  const folders: string[] = [];
  const entries = readdirSync(currentDir, { withFileTypes: true });

  for (const entry of entries) {
    if (!entry.isDirectory() || shouldSkipDir(entry.name)) {
      continue;
    }

    const relPath = relativePrefix ? `${relativePrefix}/${entry.name}` : entry.name;
    folders.push(relPath);
    folders.push(...collectFolderPaths(join(currentDir, entry.name), relPath));
  }

  return folders;
}

export function listSubfolders(vaultFolderPath: string): string[] {
  if (!existsSync(vaultFolderPath)) {
    return [];
  }

  const entries = readdirSync(vaultFolderPath, { withFileTypes: true });
  const folders: string[] = [];

  const hasRootMarkdown = entries.some(
    (entry) => entry.isFile() && entry.name.endsWith('.md'),
  );

  if (hasRootMarkdown) {
    folders.push('(root)');
  }

  folders.push(...collectFolderPaths(vaultFolderPath, ''));

  return folders.sort((left, right) => {
    if (left === '(root)') {
      return -1;
    }

    if (right === '(root)') {
      return 1;
    }

    return left.localeCompare(right);
  });
}

export function listMarkdownFiles(vaultFolderPath: string, options: ScanOptions = {}): string[] {
  const includedSubfolders = options.includedSubfolders ?? [];

  return collectMarkdownFiles(vaultFolderPath).filter((filePath) => {
    try {
      const stats = statSync(filePath);
      if (!stats.isFile() || stats.size === 0) {
        return false;
      }

      const relativePath = relative(vaultFolderPath, filePath);
      return isFileIncluded(relativePath, includedSubfolders);
    } catch {
      return false;
    }
  });
}

export function pickRandomMarkdownFile(
  vaultFolderPath: string,
  options: ScanOptions = {},
  excludePath?: string | null,
): string | null {
  const files = listMarkdownFiles(vaultFolderPath, options);
  if (files.length === 0) {
    return null;
  }

  const candidates = excludePath ? files.filter((file) => file !== excludePath) : files;
  const pool = candidates.length > 0 ? candidates : files;
  const index = randomInt(pool.length);
  return pool[index] ?? null;
}

export function readMarkdownNote(vaultFolderPath: string, filePath: string): MarkdownNote {
  const rawContent = readFileSync(filePath, 'utf8');
  const content = stripFrontmatter(rawContent);
  const stats = statSync(filePath);

  return {
    filePath,
    relativePath: relative(vaultFolderPath, filePath),
    title: extractTitle(content, filePath),
    content,
    mtimeMs: stats.mtimeMs,
  };
}

export function getParentFolder(relativePath: string): string {
  const normalized = relativePath.replace(/\\/g, '/');
  const lastSlash = normalized.lastIndexOf('/');

  if (lastSlash === -1) {
    return '(root)';
  }

  return normalized.slice(0, lastSlash);
}

export function getNoteContentHash(content: string): string {
  return createHash('sha256').update(content).digest('hex');
}

export function getSummaryCacheKey(filePath: string): string {
  return createHash('sha256').update(filePath).digest('hex');
}
