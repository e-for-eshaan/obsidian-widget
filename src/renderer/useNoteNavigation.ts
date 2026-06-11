import { useCallback, useRef, useState } from 'react';

type NavigationIntent = 'related' | 'back' | 'back-to-top';

export const useNoteNavigation = () => {
  const [history, setHistory] = useState<string[]>([]);
  const intentRef = useRef<NavigationIntent | null>(null);
  const currentFilePathRef = useRef('');

  const syncCurrentFilePath = useCallback((filePath: string) => {
    currentFilePathRef.current = filePath;
  }, []);

  const handleExternalNoteUpdate = useCallback((filePath: string) => {
    const intent = intentRef.current;
    intentRef.current = null;

    if (!intent && filePath !== currentFilePathRef.current) {
      setHistory([]);
    }
  }, []);

  const navigateToRelated = useCallback((fromPath: string, toPath: string) => {
    if (fromPath && fromPath !== toPath) {
      setHistory((prev) => [...prev, fromPath]);
    }

    intentRef.current = 'related';
    return window.widgetApi.loadNote(toPath);
  }, []);

  const goBack = useCallback(() => {
    setHistory((prev) => {
      if (prev.length === 0) {
        return prev;
      }

      const target = prev[prev.length - 1];
      intentRef.current = 'back';
      void window.widgetApi.loadNote(target);
      return prev.slice(0, -1);
    });
  }, []);

  const goBackToTop = useCallback(() => {
    setHistory((prev) => {
      if (prev.length === 0) {
        return prev;
      }

      const target = prev[0];
      intentRef.current = 'back-to-top';
      void window.widgetApi.loadNote(target);
      return [];
    });
  }, []);

  const clearHistory = useCallback(() => {
    setHistory([]);
  }, []);

  return {
    canGoBack: history.length > 0,
    navigateToRelated,
    goBack,
    goBackToTop,
    clearHistory,
    handleExternalNoteUpdate,
    syncCurrentFilePath,
  };
};
