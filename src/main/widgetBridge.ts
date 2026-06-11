import { existsSync, mkdirSync, readdirSync, renameSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { spawn } from 'node:child_process';
import { app } from 'electron';
import {
  APP_GROUP_ID,
  APP_GROUP_SUFFIX,
  LEGACY_APP_GROUP_ID,
  WIDGET_STATE_FILENAME,
  notePayloadToWidgetState,
  type WidgetSharedState,
} from '../shared/widgetState';
import type { NotePayload } from '../shared/types';

function getAppGroupContainerPaths(): string[] {
  const groupContainersRoot = join(homedir(), 'Library', 'Group Containers');
  const paths = new Set<string>([
    join(groupContainersRoot, APP_GROUP_ID),
    join(groupContainersRoot, LEGACY_APP_GROUP_ID),
  ]);

  if (existsSync(groupContainersRoot)) {
    for (const entry of readdirSync(groupContainersRoot)) {
      if (entry.includes(APP_GROUP_SUFFIX)) {
        paths.add(join(groupContainersRoot, entry));
      }
    }
  }

  return [...paths];
}

function getWidgetStatePath(containerPath: string): string {
  return join(containerPath, WIDGET_STATE_FILENAME);
}

export function writeWidgetState(state: WidgetSharedState): void {
  const payload = JSON.stringify(state, null, 2);

  for (const containerPath of getAppGroupContainerPaths()) {
    mkdirSync(containerPath, { recursive: true });

    const statePath = getWidgetStatePath(containerPath);
    const tempPath = `${statePath}.tmp`;
    writeFileSync(tempPath, payload, 'utf8');
    renameSync(tempPath, statePath);
  }
}

export function syncWidgetStateFromNote(note: NotePayload): void {
  writeWidgetState(notePayloadToWidgetState(note));
  reloadNativeWidget();
}

function getWidgetReloadHelperPath(): string | null {
  const bundledPath = join(process.resourcesPath, 'WidgetReload');
  if (existsSync(bundledPath)) {
    return bundledPath;
  }

  const devPath = join(app.getAppPath(), 'macos', 'build', 'Release', 'WidgetReload');
  if (existsSync(devPath)) {
    return devPath;
  }

  return null;
}

export function reloadNativeWidget(): void {
  const helperPath = getWidgetReloadHelperPath();
  if (!helperPath) {
    return;
  }

  const child = spawn(helperPath, [], {
    detached: true,
    stdio: 'ignore',
  });
  child.unref();
}
