import { useCallback, useEffect, useMemo, useState } from 'react';
import type { AspectRatio, WidgetSettings } from '../shared/types';
import { MAX_FONT_SIZE_PX, MIN_FONT_SIZE_PX } from '../shared/types';
import { buildFolderTree, type FolderTreeNode } from './folderTree';
import styles from './SettingsPanel.module.css';

interface SettingsTriggerProps {
  isActive: boolean;
  onClick: () => void;
  className?: string;
  activeClassName?: string;
}

export const SettingsTrigger = ({
  isActive,
  onClick,
  className = '',
  activeClassName = '',
}: SettingsTriggerProps) => (
  <button
    type="button"
    className={`${className} ${isActive ? activeClassName : ''}`.trim()}
    onClick={onClick}
    aria-label="Settings"
    aria-expanded={isActive}
  >
    <SettingsIcon />
  </button>
);

interface SettingsPanelProps {
  settings: WidgetSettings;
  onClose: () => void;
  onChooseFolder: () => void;
  onToggleSubfolder: (folder: string) => void;
  onAspectRatioChange: (aspectRatio: AspectRatio) => void;
  onFontSizeChange: (fontSizePx: number) => void;
  onRefreshNow: () => void;
  onRegenerateSummary: () => void;
  canRegenerateSummary: boolean;
}

export const SettingsPanel = ({
  settings,
  onClose,
  onChooseFolder,
  onToggleSubfolder,
  onAspectRatioChange,
  onFontSizeChange,
  onRefreshNow,
  onRegenerateSummary,
  canRegenerateSummary,
}: SettingsPanelProps) => {
  const [subfoldersOpen, setSubfoldersOpen] = useState(false);
  const [collapsedPaths, setCollapsedPaths] = useState<Set<string>>(() => new Set());
  const folderLabel = getFolderLabel(settings.vaultFolderPath);
  const allSubfoldersAllowed = settings.includedSubfolders.length === 0;

  const folderTree = useMemo(
    () => buildFolderTree(settings.availableSubfolders),
    [settings.availableSubfolders],
  );

  useEffect(() => {
    setCollapsedPaths(new Set());
  }, [settings.vaultFolderPath]);

  const handleToggleCollapse = useCallback((folderPath: string) => {
    setCollapsedPaths((prev) => {
      const next = new Set(prev);
      if (next.has(folderPath)) {
        next.delete(folderPath);
      } else {
        next.add(folderPath);
      }
      return next;
    });
  }, []);

  const handleDecreaseFont = useCallback(() => {
    onFontSizeChange(Math.max(MIN_FONT_SIZE_PX, settings.fontSizePx - 1));
  }, [onFontSizeChange, settings.fontSizePx]);

  const handleIncreaseFont = useCallback(() => {
    onFontSizeChange(Math.min(MAX_FONT_SIZE_PX, settings.fontSizePx + 1));
  }, [onFontSizeChange, settings.fontSizePx]);

  useEffect(() => {
    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose();
      }
    };

    document.addEventListener('keydown', handleEscape);
    return () => {
      document.removeEventListener('keydown', handleEscape);
    };
  }, [onClose]);

  return (
    <section className={styles.panel} aria-label="Settings">
      <div className={styles.folderRow}>
        <span className={styles.folderPath} title={settings.vaultFolderPath}>
          {folderLabel}
        </span>
        <button type="button" className={styles.browseButton} onClick={onChooseFolder}>
          Browse
        </button>
      </div>

      <div className={styles.subfolderSection}>
        <button
          type="button"
          className={styles.nestedToggle}
          onClick={() => setSubfoldersOpen((prev) => !prev)}
          aria-expanded={subfoldersOpen}
        >
          <ChevronIcon isExpanded={subfoldersOpen} />
          <span>Subfolders</span>
          <span className={styles.badge}>
            {allSubfoldersAllowed ? 'All folders' : `${settings.includedSubfolders.length} selected`}
          </span>
        </button>

        {subfoldersOpen ? (
          <div className={styles.subfolderList}>
            {folderTree.length === 0 ? (
              <span className={styles.emptyHint}>None</span>
            ) : (
              folderTree.map((node) => (
                <FolderTreeNodeRow
                  key={node.path}
                  node={node}
                  depth={0}
                  collapsedPaths={collapsedPaths}
                  includedSubfolders={settings.includedSubfolders}
                  onToggleCollapse={handleToggleCollapse}
                  onToggleFolder={onToggleSubfolder}
                />
              ))
            )}
          </div>
        ) : null}
      </div>

      <div className={styles.inlineRow}>
        <span className={styles.rowLabel}>Layout</span>
        <div className={styles.segmented}>
          <button
            type="button"
            className={`${styles.segment} ${settings.aspectRatio === 'square' ? styles.segmentActive : ''}`}
            onClick={() => onAspectRatioChange('square')}
          >
            Square
          </button>
          <button
            type="button"
            className={`${styles.segment} ${settings.aspectRatio === 'rectangle' ? styles.segmentActive : ''}`}
            onClick={() => onAspectRatioChange('rectangle')}
          >
            Rectangle
          </button>
        </div>
      </div>

      <div className={styles.inlineRow}>
        <span className={styles.rowLabel}>Font size</span>
        <div className={styles.fontRow}>
          <button
            type="button"
            className={styles.fontStep}
            onClick={handleDecreaseFont}
            disabled={settings.fontSizePx <= MIN_FONT_SIZE_PX}
            aria-label="Decrease font size"
          >
            −
          </button>
          <input
            type="range"
            className={styles.fontSlider}
            min={MIN_FONT_SIZE_PX}
            max={MAX_FONT_SIZE_PX}
            step={1}
            value={settings.fontSizePx}
            onChange={(event) => onFontSizeChange(Number(event.target.value))}
            aria-label="Font size"
          />
          <button
            type="button"
            className={styles.fontStep}
            onClick={handleIncreaseFont}
            disabled={settings.fontSizePx >= MAX_FONT_SIZE_PX}
            aria-label="Increase font size"
          >
            +
          </button>
          <span className={styles.fontBadge}>{settings.fontSizePx}</span>
        </div>
      </div>

      <span className={styles.meta}>Refreshes every {settings.refreshIntervalHours} hours</span>

      <div className={styles.actions}>
        <button type="button" className={styles.actionPrimary} onClick={onRefreshNow}>
          Refresh
        </button>
        <button
          type="button"
          className={styles.actionSecondary}
          onClick={onRegenerateSummary}
          disabled={!canRegenerateSummary}
        >
          Regenerate
        </button>
      </div>
    </section>
  );
};

interface FolderTreeNodeRowProps {
  node: FolderTreeNode;
  depth: number;
  collapsedPaths: Set<string>;
  includedSubfolders: string[];
  onToggleCollapse: (folderPath: string) => void;
  onToggleFolder: (folderPath: string) => void;
}

const FolderTreeNodeRow = ({
  node,
  depth,
  collapsedPaths,
  includedSubfolders,
  onToggleCollapse,
  onToggleFolder,
}: FolderTreeNodeRowProps) => {
  const hasChildren = node.children.length > 0;
  const isCollapsed = collapsedPaths.has(node.path);
  const checked = includedSubfolders.includes(node.path);

  return (
    <>
      <div className={styles.subfolderRow} style={{ paddingLeft: `${depth * 12}px` }}>
        <button
          type="button"
          className={`${styles.subfolderChevron} ${hasChildren ? '' : styles.subfolderChevronHidden}`}
          onClick={() => onToggleCollapse(node.path)}
          aria-label={isCollapsed ? `Expand ${node.name}` : `Collapse ${node.name}`}
          aria-expanded={hasChildren ? !isCollapsed : undefined}
          tabIndex={hasChildren ? 0 : -1}
        >
          {hasChildren ? <ChevronIcon isExpanded={!isCollapsed} /> : null}
        </button>

        <label className={styles.subfolderItem} title={node.path}>
          <input
            type="checkbox"
            className={styles.subfolderInput}
            checked={checked}
            onChange={() => onToggleFolder(node.path)}
          />
          <span className={styles.subfolderCheck} aria-hidden="true" />
          <span className={styles.subfolderName}>{node.name}</span>
        </label>
      </div>

      {hasChildren && !isCollapsed
        ? node.children.map((child) => (
            <FolderTreeNodeRow
              key={child.path}
              node={child}
              depth={depth + 1}
              collapsedPaths={collapsedPaths}
              includedSubfolders={includedSubfolders}
              onToggleCollapse={onToggleCollapse}
              onToggleFolder={onToggleFolder}
            />
          ))
        : null}
    </>
  );
};

const SettingsIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l-.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.1a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z" />
    <circle cx="12" cy="12" r="3" />
  </svg>
);

const ChevronIcon = ({ isExpanded }: { isExpanded: boolean }) => (
  <svg
    className={`${styles.chevron} ${isExpanded ? styles.chevronExpanded : ''}`}
    xmlns="http://www.w3.org/2000/svg"
    width="10"
    height="10"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2.5"
    strokeLinecap="round"
    strokeLinejoin="round"
    aria-hidden="true"
  >
    <path d="M9 18l6-6-6-6" />
  </svg>
);

function getFolderLabel(vaultFolderPath: string): string {
  if (!vaultFolderPath) {
    return 'No folder';
  }

  const parts = vaultFolderPath.split('/').filter(Boolean);
  if (parts.length <= 2) {
    return vaultFolderPath;
  }

  return `…/${parts.slice(-2).join('/')}`;
}
