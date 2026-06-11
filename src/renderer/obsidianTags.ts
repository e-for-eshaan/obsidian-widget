const CODE_SEGMENT_PATTERN = /(```[\s\S]*?```|`[^`\n]+`)/g;
const WIKI_LINK_PATTERN = /\[\[([^\]|#]+)(?:#([^\]|]+))?(?:\|([^\]]+))?\]\]/g;
const LINE_TAG_PATTERN = /^#([a-zA-Z][\w/-]*)$/gm;
const INLINE_TAG_PATTERN = /(?<![\w/`])#([a-zA-Z][\w/-]*)/g;

function wrapTag(tagBody: string): string {
  return `[#${tagBody}](obsidian-tag:${tagBody})`;
}

function getWikiDisplayText(target: string, alias?: string): string {
  if (alias?.trim()) {
    return alias.trim();
  }

  const basename = target.trim().split('/').pop() ?? target.trim();
  return basename.replace(/\.md$/i, '');
}

function wrapWikiLink(target: string, heading?: string, alias?: string): string {
  const display = getWikiDisplayText(target, alias);
  const linkTarget = heading ? `${target.trim()}#${heading.trim()}` : target.trim();

  return `[${display}](obsidian-wiki:${encodeURIComponent(linkTarget)})`;
}

function transformTextSegment(segment: string): string {
  const withWikiLinks = segment.replace(WIKI_LINK_PATTERN, (_match, target: string, heading?: string, alias?: string) => {
    return wrapWikiLink(target, heading, alias);
  });

  const withLineTags = withWikiLinks.replace(LINE_TAG_PATTERN, (_match, tagBody: string) => wrapTag(tagBody));
  return withLineTags.replace(INLINE_TAG_PATTERN, (_match, tagBody: string) => wrapTag(tagBody));
}

export function preprocessObsidianContent(content: string): string {
  const segments: string[] = [];
  let lastIndex = 0;

  for (const match of content.matchAll(CODE_SEGMENT_PATTERN)) {
    const matchIndex = match.index ?? 0;

    if (matchIndex > lastIndex) {
      segments.push(transformTextSegment(content.slice(lastIndex, matchIndex)));
    }

    segments.push(match[0]);
    lastIndex = matchIndex + match[0].length;
  }

  if (lastIndex < content.length) {
    segments.push(transformTextSegment(content.slice(lastIndex)));
  }

  return segments.length > 0 ? segments.join('') : transformTextSegment(content);
}

export function isObsidianTagHref(href?: string): boolean {
  return Boolean(href?.startsWith('obsidian-tag:'));
}

export function isObsidianWikiHref(href?: string): boolean {
  return Boolean(href?.startsWith('obsidian-wiki:'));
}

export function getObsidianWikiTarget(href: string): string {
  return decodeURIComponent(href.slice('obsidian-wiki:'.length));
}
