const LANGUAGE_ALIASES: Record<string, string> = {
  js: 'javascript',
  ts: 'typescript',
  tsx: 'tsx',
  jsx: 'jsx',
  py: 'python',
  sh: 'bash',
  shell: 'bash',
  zsh: 'bash',
  yml: 'yaml',
  md: 'markdown',
  'c++': 'cpp',
  cs: 'csharp',
  rs: 'rust',
  go: 'go',
  kt: 'kotlin',
  rb: 'ruby',
};

export function normalizeCodeLanguage(raw?: string): string {
  if (!raw?.trim()) {
    return 'text';
  }

  const lower = raw.trim().toLowerCase();
  return LANGUAGE_ALIASES[lower] ?? lower;
}
