import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { spawn } from 'node:child_process';
import { getNoteContentHash, getSummaryCacheKey } from './obsidianScanner';
import { getSummaryCacheDir, type AppConfig } from './config';
import { formatSummaryBullets } from './summaryFormat';

const SUMMARY_TIMEOUT_MS = 120_000;
const MAX_LLM_RELATED_NOTES = 8;

export interface LlmRelatedNote {
  title: string;
}

export interface NoteSummaryResult {
  summary: string;
  relatedNotes: LlmRelatedNote[];
}

interface CachedNoteSummary {
  contentHash: string;
  summary: string;
  relatedNotes: LlmRelatedNote[];
}

function buildPrompt(title: string, content: string): string {
  const trimmedContent = content.slice(0, 12_000);
  return [
    'Return a single JSON object and nothing else — no preamble, no explanation, no markdown fences.',
    '{"summary":"- First short point\\n- Second short point\\n- Third short point","relatedNotes":[{"title":"..."}]}',
    '',
    'Rules:',
    '- summary: Markdown bullet list ONLY. Every line must start with "- ". Use 2-5 bullets. Keep each bullet under 12 words.',
    `- relatedNotes: up to ${MAX_LLM_RELATED_NOTES} notes linked via [[wiki links]] in the note or clearly related. Use exact note titles from the note body.`,
    '- If none apply, return "relatedNotes":[]',
    '- Do not mention permissions, vault access, or that you cannot read files.',
    '',
    `Note title: ${title}`,
    '',
    trimmedContent,
  ].join('\n');
}

function readCachedSummary(
  cacheDir: string,
  cacheKey: string,
  contentHash: string,
): CachedNoteSummary | null {
  const cachePath = join(cacheDir, `${cacheKey}.json`);
  if (!existsSync(cachePath)) {
    return null;
  }

  try {
    const parsed = JSON.parse(readFileSync(cachePath, 'utf8')) as CachedNoteSummary;
    if (!parsed.summary || parsed.contentHash !== contentHash) {
      return null;
    }

    return normalizeCachedSummary({
      contentHash: parsed.contentHash,
      summary: parsed.summary.trim(),
      relatedNotes: Array.isArray(parsed.relatedNotes) ? parsed.relatedNotes : [],
    });
  } catch {
    return null;
  }
}

function writeCachedSummary(
  cacheDir: string,
  cacheKey: string,
  result: CachedNoteSummary,
): void {
  const cachePath = join(cacheDir, `${cacheKey}.json`);
  writeFileSync(cachePath, JSON.stringify(result, null, 2), 'utf8');
}

function findEmbeddedJsonObject(text: string): string | null {
  const start = text.indexOf('{');
  if (start === -1) {
    return null;
  }

  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let index = start; index < text.length; index += 1) {
    const char = text[index];

    if (escaped) {
      escaped = false;
      continue;
    }

    if (char === '\\' && inString) {
      escaped = true;
      continue;
    }

    if (char === '"') {
      inString = !inString;
      continue;
    }

    if (inString) {
      continue;
    }

    if (char === '{') {
      depth += 1;
    }

    if (char === '}') {
      depth -= 1;
      if (depth === 0) {
        return text.slice(start, index + 1);
      }
    }
  }

  return null;
}

function extractJsonPayload(raw: string): string {
  const trimmed = raw.trim();
  const fencedMatch = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  if (fencedMatch?.[1]) {
    return fencedMatch[1].trim();
  }

  const embedded = findEmbeddedJsonObject(trimmed);
  if (embedded) {
    return embedded;
  }

  return trimmed;
}

function normalizeRelatedNotes(value: unknown): LlmRelatedNote[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .filter((item): item is LlmRelatedNote => {
      return Boolean(item) && typeof item === 'object' && typeof item.title === 'string';
    })
    .map((item) => ({ title: item.title.trim() }))
    .filter((item) => item.title.length > 0)
    .slice(0, MAX_LLM_RELATED_NOTES);
}

function tryParseSummaryJson(jsonText: string): NoteSummaryResult | null {
  try {
    const parsed = JSON.parse(jsonText) as Partial<NoteSummaryResult>;
    const summary = typeof parsed.summary === 'string' ? parsed.summary.trim() : '';

    if (!summary) {
      return null;
    }

    return {
      summary: formatSummaryBullets(summary),
      relatedNotes: normalizeRelatedNotes(parsed.relatedNotes),
    };
  } catch {
    return null;
  }
}

function looksLikeMalformedSummary(summary: string): boolean {
  const trimmed = summary.trim();
  return trimmed.startsWith('{') || trimmed.includes('"summary":') || trimmed.includes('"relatedNotes"');
}

function parseSummaryResponse(raw: string): NoteSummaryResult {
  const candidates = new Set<string>();

  candidates.add(extractJsonPayload(raw));

  const embedded = findEmbeddedJsonObject(raw);
  if (embedded) {
    candidates.add(embedded);
  }

  for (const candidate of candidates) {
    const parsed = tryParseSummaryJson(candidate);
    if (parsed) {
      return parsed;
    }
  }

  const stripped = raw.replace(/\{[\s\S]*\}/, '').trim();
  if (stripped) {
    return {
      summary: formatSummaryBullets(stripped),
      relatedNotes: [],
    };
  }

  return {
    summary: 'Summary could not be parsed. Use Regenerate summary in settings.',
    relatedNotes: [],
  };
}

function normalizeCachedSummary(cached: CachedNoteSummary): CachedNoteSummary {
  if (!looksLikeMalformedSummary(cached.summary)) {
    return cached;
  }

  const repaired = parseSummaryResponse(cached.summary);
  return {
    contentHash: cached.contentHash,
    summary: repaired.summary,
    relatedNotes: repaired.relatedNotes.length > 0 ? repaired.relatedNotes : cached.relatedNotes,
  };
}

function runClaude(config: AppConfig, prompt: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const args = [
      '-p',
      '--no-session-persistence',
      '--permission-mode',
      'dontAsk',
      '--output-format',
      'text',
    ];

    const child = spawn(config.claudeBinary, args, {
      env: {
        ...process.env,
        CC_HEADLESS: '1',
      },
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    child.stdin.write(prompt);
    child.stdin.end();

    let stdout = '';
    let stderr = '';

    const timeout = setTimeout(() => {
      child.kill('SIGTERM');
      reject(new Error('Claude CLI timed out after 120 seconds'));
    }, SUMMARY_TIMEOUT_MS);

    child.stdout.on('data', (chunk: Buffer) => {
      stdout += chunk.toString();
    });

    child.stderr.on('data', (chunk: Buffer) => {
      stderr += chunk.toString();
    });

    child.on('error', (error) => {
      clearTimeout(timeout);
      reject(new Error(`Failed to run Claude CLI (${config.claudeBinary}): ${error.message}`));
    });

    child.on('close', (code) => {
      clearTimeout(timeout);
      const output = stdout.trim();

      if (code !== 0) {
        reject(new Error(stderr.trim() || `Claude CLI exited with code ${code}`));
        return;
      }

      if (!output) {
        reject(
          new Error(
            'Claude CLI returned empty output. Run `claude -p "hello"` in Terminal to verify your CLI setup.',
          ),
        );
        return;
      }

      resolve(output);
    });
  });
}

export async function summarizeNote(
  config: AppConfig,
  title: string,
  content: string,
  filePath: string,
  options: { bypassCache?: boolean } = {},
): Promise<NoteSummaryResult> {
  const cacheDir = getSummaryCacheDir(config);
  const contentHash = getNoteContentHash(content);
  const cacheKey = getSummaryCacheKey(filePath);

  if (!options.bypassCache) {
    const cached = readCachedSummary(cacheDir, cacheKey, contentHash);
    if (cached) {
      return {
        summary: formatSummaryBullets(cached.summary),
        relatedNotes: cached.relatedNotes,
      };
    }
  }

  const rawResponse = await runClaude(config, buildPrompt(title, content));
  const result = parseSummaryResponse(rawResponse);
  writeCachedSummary(cacheDir, cacheKey, {
    contentHash,
    summary: result.summary,
    relatedNotes: result.relatedNotes,
  });
  return result;
}
