import { useCallback, useMemo, type MouseEvent } from 'react';
import ReactMarkdown, { defaultUrlTransform } from 'react-markdown';
import remarkGfm from 'remark-gfm';
import '@fontsource/jetbrains-mono/400.css';
import '@fontsource/jetbrains-mono/500.css';
import { DEFAULT_FONT_SIZE_PX } from '../shared/types';
import { getObsidianWikiTarget, isObsidianTagHref, isObsidianWikiHref, preprocessObsidianContent } from './obsidianTags';
import { MarkdownCodeBlock } from './MarkdownCodeBlock';
import styles from './MarkdownRenderer.module.css';

type MarkdownVariant = 'summary' | 'original';

interface MarkdownRendererProps {
  content: string;
  variant?: MarkdownVariant;
  isError?: boolean;
  fontSizePx?: number;
  onWikiLinkClick?: (wikiTarget: string) => void;
}

const allowObsidianUrlTransform = (url: string) => {
  if (url.startsWith('obsidian-wiki:') || url.startsWith('obsidian-tag:')) {
    return url;
  }

  return defaultUrlTransform(url);
};

export const MarkdownRenderer = ({
  content,
  variant = 'original',
  isError = false,
  fontSizePx = DEFAULT_FONT_SIZE_PX,
  onWikiLinkClick,
}: MarkdownRendererProps) => {
  const className = [
    styles.markdown,
    variant === 'summary' ? styles.summary : styles.original,
    isError ? styles.error : '',
  ]
    .filter(Boolean)
    .join(' ');

  const renderedContent = useMemo(() => preprocessObsidianContent(content), [content]);

  const handleExternalLinkClick = useCallback((event: MouseEvent<HTMLAnchorElement>, href?: string) => {
    event.preventDefault();
    if (href) {
      void window.widgetApi.openExternal(href);
    }
  }, []);

  const handleWikiLinkClick = useCallback(
    (event: MouseEvent<HTMLButtonElement>, wikiTarget: string) => {
      event.preventDefault();
      onWikiLinkClick?.(wikiTarget);
    },
    [onWikiLinkClick],
  );

  return (
    <div className={className} style={{ fontSize: `${fontSizePx}px` }}>
      <ReactMarkdown
        remarkPlugins={[remarkGfm]}
        urlTransform={allowObsidianUrlTransform}
        components={{
          pre: ({ children }) => <>{children}</>,
          code: MarkdownCodeBlock,
          a: ({ href, children, ...props }) => {
            if (isObsidianTagHref(href)) {
              return <span className={styles.tag}>{children}</span>;
            }

            if (isObsidianWikiHref(href)) {
              const wikiTarget = href ? getObsidianWikiTarget(href) : '';
              return (
                <button
                  type="button"
                  className={styles.wikiLink}
                  onClick={(event) => handleWikiLinkClick(event, wikiTarget)}
                >
                  {children}
                </button>
              );
            }

            return (
              <a href={href} {...props} onClick={(event) => handleExternalLinkClick(event, href)}>
                {children}
              </a>
            );
          },
        }}
      >
        {renderedContent}
      </ReactMarkdown>
    </div>
  );
};
