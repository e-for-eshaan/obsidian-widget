function splitSummarySentences(text: string): string[] {
  const sentences = text
    .split(/(?<=[.!?])\s+/)
    .map((part) => part.trim())
    .filter(Boolean);

  return sentences.length > 0 ? sentences : [text.trim()];
}

function hasBulletLines(lines: string[]): boolean {
  return lines.some((line) => /^[-*+•]\s+/.test(line));
}

export function formatSummaryBullets(summary: string): string {
  const trimmed = summary.trim();
  if (!trimmed) {
    return trimmed;
  }

  const lines = trimmed.split('\n').map((line) => line.trim()).filter(Boolean);

  if (hasBulletLines(lines)) {
    return lines.map((line) => line.replace(/^[*+•]\s+/, '- ')).join('\n');
  }

  const paragraph = lines.join(' ');
  const sentences = splitSummarySentences(paragraph);

  if (sentences.length === 1) {
    return `- ${sentences[0]}`;
  }

  return sentences.map((sentence) => `- ${sentence}`).join('\n');
}
