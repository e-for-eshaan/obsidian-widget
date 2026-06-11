import { useEffect, useState } from 'react';
import styles from './NoteLoader.module.css';

const LOADING_STEPS = [
  'Reading note',
  'Generating summary',
  'Finding related notes',
];

interface NoteLoaderProps {
  message?: string;
}

export const NoteLoader = ({ message }: NoteLoaderProps) => {
  const [stepIndex, setStepIndex] = useState(0);

  useEffect(() => {
    const interval = setInterval(() => {
      setStepIndex((current) => (current + 1) % LOADING_STEPS.length);
    }, 2400);

    return () => {
      clearInterval(interval);
    };
  }, []);

  const stepLabel = LOADING_STEPS[stepIndex];
  const detailMessage = message?.trim();

  return (
    <div className={styles.loader} role="status" aria-live="polite" aria-busy="true">
      <div className={styles.iconWrap} aria-hidden="true">
        <DocumentPulseIcon />
      </div>

      <div className={styles.skeleton}>
        <span className={styles.skeletonLine} />
        <span className={`${styles.skeletonLine} ${styles.skeletonLineMedium}`} />
        <span className={`${styles.skeletonLine} ${styles.skeletonLineShort}`} />
      </div>

      <div className={styles.progressTrack} aria-hidden="true">
        <span className={styles.progressBar} />
      </div>

      <p className={styles.stepLabel} key={stepLabel}>
        {stepLabel}
        <span className={styles.ellipsis} aria-hidden="true">
          <span className={styles.dot} />
          <span className={styles.dot} />
          <span className={styles.dot} />
        </span>
      </p>

      {detailMessage ? <p className={styles.detail}>{detailMessage}</p> : null}
    </div>
  );
};

const DocumentPulseIcon = () => (
  <svg
    className={styles.icon}
    xmlns="http://www.w3.org/2000/svg"
    width="28"
    height="28"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="1.5"
    strokeLinecap="round"
    strokeLinejoin="round"
  >
    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
    <path d="M14 2v6h6" />
    <path d="M8 13h8" />
    <path d="M8 17h5" />
  </svg>
);
