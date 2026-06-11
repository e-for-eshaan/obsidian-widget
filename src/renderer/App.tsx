import { useCallback, useEffect, useState, type MouseEvent } from 'react';
import type { ContentView, NotePayload, WidgetSettings } from '../shared/types';
import { SettingsPanel, SettingsTrigger } from './SettingsPanel';
import { MarkdownRenderer } from './MarkdownRenderer';
import { NoteSummaryMeta } from './NoteSummaryMeta';
import { NoteLoader } from './NoteLoader';
import { useNoteNavigation } from './useNoteNavigation';
import styles from './App.module.css';

const EMPTY_NOTE: NotePayload = {
  title: 'Obsidian Widget',
  summary: 'Loading your note…',
  content: '',
  relativePath: '',
  filePath: '',
  parentFolder: '',
  relatedNotes: [],
  nextRefreshAt: new Date().toISOString(),
  status: 'loading',
};

const EMPTY_SETTINGS: WidgetSettings = {
  vaultFolderPath: '',
  includedSubfolders: [],
  refreshIntervalHours: 4,
  contentView: 'summary',
  fontSizePx: 11,
  availableSubfolders: [],
};

export const App = () => {
  const [note, setNote] = useState<NotePayload>(EMPTY_NOTE);
  const [settings, setSettings] = useState<WidgetSettings>(EMPTY_SETTINGS);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const {
    canGoBack,
    navigateToRelated,
    goBack,
    goBackToTop,
    clearHistory,
    handleExternalNoteUpdate,
    syncCurrentFilePath,
  } = useNoteNavigation();

  useEffect(() => {
    void window.widgetApi.getNote().then((payload) => {
      if (payload) {
        syncCurrentFilePath(payload.filePath);
        setNote(payload);
      }
    });

    void window.widgetApi.getSettings().then((payload) => {
      setSettings(payload);
    });

    const unsubscribeNote = window.widgetApi.onNoteUpdated((payload) => {
      handleExternalNoteUpdate(payload.filePath);
      syncCurrentFilePath(payload.filePath);
      setNote(payload);
    });

    const unsubscribeSettings = window.widgetApi.onSettingsUpdated((payload) => {
      setSettings(payload);
    });

    return () => {
      unsubscribeNote();
      unsubscribeSettings();
    };
  }, [handleExternalNoteUpdate, syncCurrentFilePath]);

  useEffect(() => {
    setSettingsOpen(false);
  }, [note.filePath]);

  const handleChooseFolder = useCallback(() => {
    clearHistory();
    void window.widgetApi.chooseFolder().then((nextSettings) => {
      setSettings(nextSettings);
    });
  }, [clearHistory]);

  const handleToggleSubfolder = useCallback(
    (folder: string) => {
      const isSelected = settings.includedSubfolders.includes(folder);
      const nextIncluded = isSelected
        ? settings.includedSubfolders.filter((item) => item !== folder)
        : [...settings.includedSubfolders, folder];

      void window.widgetApi.updateSettings({ includedSubfolders: nextIncluded }).then((nextSettings) => {
        setSettings(nextSettings);
      });
    },
    [settings.includedSubfolders],
  );

  const handleFontSizeChange = useCallback((fontSizePx: number) => {
    void window.widgetApi.updateSettings({ fontSizePx }).then((nextSettings) => {
      setSettings(nextSettings);
    });
  }, []);

  const handleContentViewChange = useCallback((contentView: ContentView) => {
    void window.widgetApi.updateSettings({ contentView }).then((nextSettings) => {
      setSettings(nextSettings);
    });
  }, []);

  const handleLoadRelatedNote = useCallback(
    (filePath: string) => {
      void navigateToRelated(note.filePath, filePath);
    },
    [navigateToRelated, note.filePath],
  );

  const handleWikiLinkClick = useCallback(
    (wikiTarget: string) => {
      void window.widgetApi.resolveWikiLink(wikiTarget).then((filePath) => {
        if (filePath && filePath !== note.filePath) {
          void navigateToRelated(note.filePath, filePath);
        }
      });
    },
    [navigateToRelated, note.filePath],
  );

  const handleForceRefresh = useCallback(() => {
    clearHistory();
    void window.widgetApi.forceRefresh().then((payload) => {
      if (payload) {
        syncCurrentFilePath(payload.filePath);
        setNote(payload);
      }
    });
  }, [clearHistory, syncCurrentFilePath]);

  const handleOpenInObsidian = useCallback(() => {
    if (note.filePath) {
      void window.widgetApi.openNote(note.filePath);
    }
  }, [note.filePath]);

  const handleRefreshNow = useCallback(() => {
    clearHistory();
    void window.widgetApi.refreshNow().then((payload) => {
      if (payload) {
        syncCurrentFilePath(payload.filePath);
        setNote(payload);
      }
    });
  }, [clearHistory, syncCurrentFilePath]);

  const handleRegenerateSummary = useCallback(() => {
    void window.widgetApi.regenerateSummary().then((payload) => {
      if (payload) {
        setNote(payload);
      }
    });
  }, []);

  const handleToggleSettings = useCallback(() => {
    setSettingsOpen((prev) => !prev);
  }, []);

  const handleCloseSettings = useCallback(() => {
    setSettingsOpen(false);
  }, []);

  const isLoading = note.status === 'loading';
  const hasOriginal = Boolean(note.content);
  const showOriginal = settings.contentView === 'original' && hasOriginal;
  const showSummaryLoader = isLoading && settings.contentView === 'summary';

  return (
    <div className={styles.root}>
      <article className={styles.card}>
        <div className={styles.toolbar}>
          <ForceRefreshButton
            onClick={handleForceRefresh}
            isLoading={note.status === 'loading'}
          />
          <OpenInObsidianButton
            onClick={handleOpenInObsidian}
            disabled={!note.filePath || note.status === 'loading'}
          />
          <SettingsTrigger
            isActive={settingsOpen}
            onClick={handleToggleSettings}
            className={styles.iconButton}
            activeClassName={styles.iconButtonActive}
          />
        </div>

        <section className={styles.noteSection}>
          <div className={styles.headBlock}>
            <div className={styles.navRow}>
              {canGoBack ? (
                <NavigationBackButton
                  onBack={goBack}
                  onBackToTop={goBackToTop}
                  disabled={isLoading}
                />
              ) : null}
              <ContentViewTabs
                activeView={settings.contentView}
                onChange={handleContentViewChange}
                originalDisabled={!hasOriginal}
                summaryLoading={isLoading}
              />
            </div>
            {settingsOpen ? (
              <SettingsPanel
                settings={settings}
                onClose={handleCloseSettings}
                onChooseFolder={handleChooseFolder}
                onToggleSubfolder={handleToggleSubfolder}
                onFontSizeChange={handleFontSizeChange}
                onRefreshNow={handleRefreshNow}
                onRegenerateSummary={handleRegenerateSummary}
                canRegenerateSummary={Boolean(note.filePath) && note.status !== 'loading'}
              />
            ) : null}
            <h1 className={styles.title}>{note.title}</h1>
          </div>

          {showOriginal ? (
            <MarkdownRenderer
              content={note.content}
              variant="original"
              fontSizePx={settings.fontSizePx}
              onWikiLinkClick={handleWikiLinkClick}
            />
          ) : showSummaryLoader ? (
            <NoteLoader message={note.summary} />
          ) : (
            <>
              <MarkdownRenderer
                content={note.summary}
                variant="summary"
                isError={note.status === 'error'}
                fontSizePx={settings.fontSizePx}
                onWikiLinkClick={handleWikiLinkClick}
              />

              {note.status === 'ready' ? (
                <NoteSummaryMeta
                  noteKey={note.filePath}
                  parentFolder={note.parentFolder}
                  relatedNotes={note.relatedNotes ?? []}
                  onSelectNote={handleLoadRelatedNote}
                />
              ) : null}
            </>
          )}

          <footer className={`${styles.footer} ${isLoading && !hasOriginal ? styles.footerLoading : ''}`}>
            {!isLoading || hasOriginal ? <span>{formatRefreshLabel(note.nextRefreshAt)}</span> : null}
          </footer>
        </section>
      </article>
    </div>
  );
};

interface NavigationBackButtonProps {
  onBack: () => void;
  onBackToTop: () => void;
  disabled: boolean;
}

const NavigationBackButton = ({ onBack, onBackToTop, disabled }: NavigationBackButtonProps) => {
  const [menuOpen, setMenuOpen] = useState(false);
  const [menuPosition, setMenuPosition] = useState({ x: 0, y: 0 });

  useEffect(() => {
    if (!menuOpen) {
      return;
    }

    const handleDismiss = () => {
      setMenuOpen(false);
    };

    document.addEventListener('click', handleDismiss);
    document.addEventListener('contextmenu', handleDismiss);

    return () => {
      document.removeEventListener('click', handleDismiss);
      document.removeEventListener('contextmenu', handleDismiss);
    };
  }, [menuOpen]);

  const handleContextMenu = useCallback((event: MouseEvent<HTMLButtonElement>) => {
      event.preventDefault();
      event.stopPropagation();
      setMenuPosition({ x: event.clientX, y: event.clientY });
      setMenuOpen(true);
  }, []);

  const handleBackToTop = useCallback(
    (event: MouseEvent<HTMLButtonElement>) => {
      event.stopPropagation();
      onBackToTop();
      setMenuOpen(false);
    },
    [onBackToTop],
  );

  return (
    <>
      <button
        type="button"
        className={styles.backButton}
        onClick={onBack}
        onContextMenu={handleContextMenu}
        disabled={disabled}
        aria-label="Back to previous note"
        title="Back · Right-click for menu"
      >
        <BackIcon />
      </button>

      {menuOpen ? (
        <div
          className={styles.contextMenu}
          style={{ top: menuPosition.y, left: menuPosition.x }}
          role="menu"
        >
          <button type="button" className={styles.contextMenuItem} role="menuitem" onClick={handleBackToTop}>
            Back to top
          </button>
        </div>
      ) : null}
    </>
  );
};

interface ContentViewTabsProps {
  activeView: ContentView;
  onChange: (view: ContentView) => void;
  originalDisabled: boolean;
  summaryLoading: boolean;
}

const ContentViewTabs = ({
  activeView,
  onChange,
  originalDisabled,
  summaryLoading,
}: ContentViewTabsProps) => (
  <div className={styles.tabBar} role="tablist" aria-label="Note view">
    <button
      type="button"
      role="tab"
      className={[
        styles.tab,
        activeView === 'summary' ? styles.tabActive : '',
        summaryLoading ? styles.tabLoading : '',
      ]
        .filter(Boolean)
        .join(' ')}
      aria-selected={activeView === 'summary'}
      aria-busy={summaryLoading}
      onClick={() => onChange('summary')}
    >
      {summaryLoading ? <span className={styles.tabSpinner} aria-hidden="true" /> : null}
      Summary
    </button>
    <button
      type="button"
      role="tab"
      className={`${styles.tab} ${activeView === 'original' ? styles.tabActive : ''}`}
      aria-selected={activeView === 'original'}
      onClick={() => onChange('original')}
      disabled={originalDisabled}
    >
      Original
    </button>
  </div>
);

const BackIcon = () => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width="12"
    height="12"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round"
    aria-hidden="true"
  >
    <path d="M19 12H5" />
    <path d="M12 19l-7-7 7-7" />
  </svg>
);

interface ForceRefreshButtonProps {
  onClick: () => void;
  isLoading: boolean;
}

const ForceRefreshButton = ({ onClick, isLoading }: ForceRefreshButtonProps) => (
  <button
    type="button"
    className={styles.iconButton}
    onClick={onClick}
    aria-label="Force refresh"
    disabled={isLoading}
    title="Force refresh — new note, new summary"
  >
    <RefreshIcon isSpinning={isLoading} />
  </button>
);

interface OpenInObsidianButtonProps {
  onClick: () => void;
  disabled: boolean;
}

const OpenInObsidianButton = ({ onClick, disabled }: OpenInObsidianButtonProps) => (
  <button
    type="button"
    className={styles.iconButton}
    onClick={onClick}
    aria-label="Open in Obsidian"
    disabled={disabled}
    title="Open in Obsidian"
  >
    <ObsidianIcon />
  </button>
);

const ObsidianIcon = () => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width="14"
    height="14"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round"
    aria-hidden="true"
  >
    <path d="M12 3 20 8v8l-8 5-8-5V8z" />
    <path d="M12 12 20 8" />
    <path d="M12 12v8" />
    <path d="M12 12 4 8" />
  </svg>
);

const RefreshIcon = ({ isSpinning }: { isSpinning: boolean }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width="14"
    height="14"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round"
    aria-hidden="true"
    className={isSpinning ? styles.spinningIcon : undefined}
  >
    <path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8" />
    <path d="M21 3v5h-5" />
  </svg>
);

function formatRefreshLabel(nextRefreshAt: string): string {
  const diffMs = Date.parse(nextRefreshAt) - Date.now();
  if (Number.isNaN(diffMs) || diffMs <= 0) {
    return 'Refreshing soon';
  }

  const hours = Math.floor(diffMs / (60 * 60 * 1000));
  const minutes = Math.floor((diffMs % (60 * 60 * 1000)) / (60 * 1000));

  if (hours > 0) {
    return `Refreshes in ${hours}h ${minutes}m`;
  }

  return `Refreshes in ${minutes}m`;
}
