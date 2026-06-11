import type { ReactNode } from 'react';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { vscDarkPlus } from 'react-syntax-highlighter/dist/esm/styles/prism';
import { normalizeCodeLanguage } from './codeBlockLanguages';
import styles from './MarkdownRenderer.module.css';

interface MarkdownCodeBlockProps {
  className?: string;
  children?: ReactNode;
}

export const MarkdownCodeBlock = ({ className, children }: MarkdownCodeBlockProps) => {
  const languageMatch = /language-([\w+#-]+)/i.exec(className ?? '');
  const code = String(children).replace(/\n$/, '');
  const isInline = !languageMatch && !code.includes('\n');

  if (isInline) {
    return (
      <code className={[className, styles.inlineCode].filter(Boolean).join(' ')}>
        {children}
      </code>
    );
  }

  const language = normalizeCodeLanguage(languageMatch?.[1]);

  return (
    <div className={styles.codeBlock}>
      <span className={styles.codeLang}>{language}</span>
      <SyntaxHighlighter
        language={language}
        style={vscDarkPlus}
        showInlineLineNumbers={false}
        customStyle={{
          margin: 0,
          padding: '1.65rem 0.75rem 0.75rem',
          borderRadius: 10,
          border: '1px solid rgba(255, 255, 255, 0.12)',
          background: 'rgba(8, 8, 14, 0.94)',
          fontSize: '0.92em',
          lineHeight: 1.65,
          boxShadow: 'inset 0 1px 0 rgba(255, 255, 255, 0.04)',
        }}
        codeTagProps={{
          style: {
            fontFamily: "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
            background: 'transparent',
            border: 'none',
            padding: 0,
            borderRadius: 0,
          },
        }}
      >
        {code}
      </SyntaxHighlighter>
    </div>
  );
};
