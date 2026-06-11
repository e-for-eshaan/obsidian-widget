import { useCallback, useEffect, useState } from 'react';
import type { RelatedNote } from '../shared/types';
import styles from './NoteSummaryMeta.module.css';

interface NoteSummaryMetaProps {
  noteKey: string;
  parentFolder: string;
  relatedNotes: RelatedNote[];
  onSelectNote: (filePath: string) => void;
}

export const NoteSummaryMeta = ({
  noteKey,
  parentFolder,
  relatedNotes,
  onSelectNote,
}: NoteSummaryMetaProps) => {
  const [isExpanded, setIsExpanded] = useState(false);

  useEffect(() => {
    setIsExpanded(false);
  }, [noteKey]);

  const handleToggle = useCallback(() => {
    setIsExpanded((prev) => !prev);
  }, []);

  const relatedCountLabel =
    relatedNotes.length === 0
      ? 'No related notes'
      : `${relatedNotes.length} related`;

  return (
    <section className={styles.section} aria-label="Note details">
      <button
        type="button"
        className={styles.toggle}
        onClick={handleToggle}
        aria-expanded={isExpanded}
      >
        <ChevronIcon isExpanded={isExpanded} />
        <span className={styles.toggleLabel}>Details</span>
        <span className={styles.toggleMeta}>
          {parentFolder} · {relatedCountLabel}
        </span>
      </button>

      {isExpanded ? (
        <div className={styles.content}>
          <div className={styles.row}>
            <span className={styles.label}>Parent folder</span>
            <span className={styles.value}>{parentFolder}</span>
          </div>

          <div className={styles.row}>
            <span className={styles.label}>Related notes</span>
            {relatedNotes.length > 0 ? (
              <div className={styles.tiles}>
                {relatedNotes.map((relatedNote) => (
                  <RelatedNoteTile
                    key={relatedNote.filePath}
                    relatedNote={relatedNote}
                    onSelect={onSelectNote}
                  />
                ))}
              </div>
            ) : (
              <span className={styles.empty}>None</span>
            )}
          </div>
        </div>
      ) : null}
    </section>
  );
};

interface RelatedNoteTileProps {
  relatedNote: RelatedNote;
  onSelect: (filePath: string) => void;
}

const RelatedNoteTile = ({ relatedNote, onSelect }: RelatedNoteTileProps) => (
  <button
    type="button"
    className={styles.tile}
    onClick={() => onSelect(relatedNote.filePath)}
    title={`Open ${relatedNote.title}`}
  >
    {relatedNote.title}
  </button>
);

const ChevronIcon = ({ isExpanded }: { isExpanded: boolean }) => (
  <svg
    className={`${styles.chevron} ${isExpanded ? styles.chevronExpanded : ''}`}
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
    <path d="M9 18l6-6-6-6" />
  </svg>
);
