# Obsidian Widget — Product Requirements Document

**Version:** 1.0  
**Last updated:** June 2026  
**Status:** Shipped (v1.0.0)  
**Platform:** macOS  

---

## 1. Executive Summary

**Obsidian Widget** is a lightweight macOS desktop widget that surfaces random notes from an Obsidian vault as AI-generated summaries. It lives as a fixed, always-on-top panel on the left edge of the screen—similar to a glanceable widget on iOS—and rotates through your notes on a configurable schedule.

The widget reads markdown files locally, sends note content to the **Claude CLI** for summarization, caches results on disk, and renders rich markdown with Obsidian-native styling (wiki links, tags, code). Users can browse related notes, switch between summary and original content, and configure vault scope without opening Obsidian.

**One-line pitch:** *A ambient second brain on your desktop—random Obsidian notes, summarized and always within reach.*

---

## 2. Problem Statement

Obsidian users accumulate large vaults over years. Valuable ideas, half-written notes, and forgotten connections sit unread because:

- Opening Obsidian requires context-switching and intentional browsing.
- Search and graph views assume you already know what to look for.
- Long notes are hard to scan quickly during brief glances at the screen.

There is no native way to passively resurface vault content on the desktop. Users who want serendipitous rediscovery must manually rotate through notes or build custom scripts.

---

## 3. Goals & Non-Goals

### Goals

| ID | Goal |
|----|------|
| G1 | Surface random vault notes passively on the desktop without opening Obsidian |
| G2 | Provide concise, readable AI summaries suitable for a small widget |
| G3 | Preserve Obsidian markdown semantics (wiki links, tags, code) in rendered output |
| G4 | Enable exploration via related notes suggested by the LLM |
| G5 | Minimize repeated LLM cost via content-hash caching |
| G6 | Stay unobtrusive: frameless, fixed position, menu-bar control |
| G7 | Persist user preferences across sessions |

### Non-Goals (v1)

| ID | Non-Goal |
|----|----------|
| NG1 | Full Obsidian feature parity (plugins, live preview editing, graph) |
| NG2 | Cross-platform support (Windows/Linux) |
| NG3 | Built-in LLM API keys or hosted summarization service |
| NG4 | Sync with Obsidian Mobile or Obsidian Sync |
| NG5 | In-widget note editing |
| NG6 | Clickable wiki links that navigate inside the widget (display-only in v1) |
| NG7 | Configurable refresh interval via UI (config-file only in v1) |

---

## 4. Target Users

### Primary persona: *The Returning Researcher*

- Maintains a large Obsidian vault (hundreds to thousands of notes)
- Uses Obsidian for thinking, not just task management
- Already uses or can install the Claude CLI
- Wants passive rediscovery of past writing during the workday
- macOS power user comfortable with menu-bar utilities

### Secondary persona: *The Focused Writer*

- Keeps a curated subfolder (e.g. `Mind/`, `Projects/`)
- Wants a single-note ambient display while writing elsewhere
- Uses subfolder filtering to limit random picks to relevant content

---

## 5. Product Overview

### Core loop

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐     ┌──────────────┐
│ Pick random │ ──▶ │ Read .md     │ ──▶ │ Summarize   │ ──▶ │ Render in    │
│ note        │     │ from vault   │     │ via Claude  │     │ widget UI    │
└─────────────┘     └──────────────┘     └─────────────┘     └──────────────┘
       ▲                                      │                      │
       │                                      ▼                      ▼
       └──────────── Scheduled refresh ◀── Cache hit?          User explores
                  (default: 4 hours)                          related notes
```

### Widget placement

- Fixed on the **left edge** of the primary display, vertically centered
- **320px** wide; height depends on aspect ratio (see §7.2)
- Frameless, transparent background with frosted-glass card
- Always on top; visible on all workspaces and fullscreen spaces
- Hidden from Dock (`app.dock.hide()` on macOS)

---

## 6. Feature Requirements

### 6.1 Vault connection

| Requirement | Description | Priority |
|-------------|-------------|----------|
| FR-1.1 | User selects an Obsidian vault folder via Browse button or menu-bar tray | P0 |
| FR-1.2 | Default vault path is preconfigured for developer; empty state prompts setup | P0 |
| FR-1.3 | Vault path persisted in `config.json` | P0 |
| FR-1.4 | Changing vault clears subfolder selection and current note pick | P0 |

**Skipped directories during scan:** `.obsidian`, `.git`, `.trash`, `templates`, `node_modules`, and any directory starting with `.`

### 6.2 Subfolder filtering

| Requirement | Description | Priority |
|-------------|-------------|----------|
| FR-2.1 | List top-level subfolders of vault (plus `(root)` if root contains `.md` files) | P0 |
| FR-2.2 | Multi-select checkboxes; empty selection = all folders included | P0 |
| FR-2.3 | Changing subfolder filter triggers immediate note refresh | P0 |
| FR-2.4 | Subfolder accordion collapsed by default in settings | P1 |

### 6.3 Note selection & refresh

| Requirement | Description | Priority |
|-------------|-------------|----------|
| FR-3.1 | Pick a random `.md` file from filtered vault on startup and on schedule | P0 |
| FR-3.2 | Default refresh interval: **4 hours** (configurable via `config.json`) | P0 |
| FR-3.3 | **Refresh now** — re-run pick logic without forcing a new note if interval not elapsed | P0 |
| FR-3.4 | **Force refresh** — always pick a new random note (excludes current note when possible) | P0 |
| FR-3.5 | Footer shows time until next scheduled refresh | P1 |
| FR-3.6 | Footer shows relative path of current note | P1 |
| FR-3.7 | Skip empty files; strip YAML frontmatter before display/summarization | P0 |
| FR-3.8 | Title extracted from first `# heading`, else filename without extension | P0 |

### 6.4 AI summarization

| Requirement | Description | Priority |
|-------------|-------------|----------|
| FR-4.1 | Summarize via **Claude CLI** (`claude -p`) in headless mode | P0 |
| FR-4.2 | LLM returns JSON: `{ summary, relatedNotes: [{ title }] }` | P0 |
| FR-4.3 | Summary: 2–3 concise sentences; markdown allowed | P0 |
| FR-4.4 | Related notes: up to 8 titles from wiki links or clearly related content | P0 |
| FR-4.5 | Note content truncated to 12,000 characters before sending to LLM | P0 |
| FR-4.6 | 120-second timeout on CLI invocation | P0 |
| FR-4.7 | Robust JSON parsing (fenced blocks, embedded JSON, plain-text fallback) | P0 |
| FR-4.8 | **Regenerate summary** — bypass cache for current note only | P0 |

### 6.5 Summary caching

| Requirement | Description | Priority |
|-------------|-------------|----------|
| FR-5.1 | Cache stored as `{sha256(filePath)}.json` in user data `.cache/summaries/` | P0 |
| FR-5.2 | Cache entry includes `contentHash` (SHA-256 of note body) | P0 |
| FR-5.3 | Cache miss on content change or missing file | P0 |
| FR-5.4 | Malformed cached summaries auto-repaired on read | P1 |

### 6.6 Related notes

| Requirement | Description | Priority |
|-------------|-------------|----------|
| FR-6.1 | LLM-suggested titles resolved to vault file paths | P0 |
| FR-6.2 | Resolution by relative path, note title, or basename | P0 |
| FR-6.3 | Clicking a related note loads it in-widget without resetting refresh timer | P0 |
| FR-6.4 | Details accordion: parent folder + related note pills | P1 |
| FR-6.5 | Details collapsed by default; resets collapse state on note change | P1 |

### 6.7 Content views (Summary / Original tabs)

| Requirement | Description | Priority |
|-------------|-------------|----------|
| FR-7.1 | Two-tab header: **Summary** (left) and **Original** (right) | P0 |
| FR-7.2 | Summary tab: AI summary + details accordion | P0 |
| FR-7.3 | Original tab: full note markdown | P0 |
| FR-7.4 | Original tab disabled while loading or when note has no content | P0 |
| FR-7.5 | Selected tab persisted as `contentView` in config | P0 |
| FR-7.6 | Tab preference survives app restart and note changes | P0 |

### 6.8 Markdown rendering

| Requirement | Description | Priority |
|-------------|-------------|----------|
| FR-8.1 | GFM markdown via `react-markdown` + `remark-gfm` | P0 |
| FR-8.2 | JetBrains Mono for summary and original body text | P0 |
| FR-8.3 | Inline `` `code` `` — orange pill styling | P0 |
| FR-8.4 | Fenced code blocks — dark panel, monospace, horizontal scroll | P0 |
| FR-8.5 | `#tags` — purple pill styling | P0 |
| FR-8.6 | `[[Wiki Links]]` — purple text, no pill; supports `\|alias` and `#heading` | P0 |
| FR-8.7 | Wiki links and tags not transformed inside code fences or inline code | P0 |
| FR-8.8 | Configurable font size: 9–16px, persisted | P0 |
| FR-8.9 | Error state: summary text shown in red | P1 |

### 6.9 Loading experience

| Requirement | Description | Priority |
|-------------|-------------|----------|
| FR-9.1 | Animated loader with skeleton lines and progress bar | P0 |
| FR-9.2 | Rotating step labels: Reading note → Generating summary → Finding related notes | P1 |
| FR-9.3 | Footer hidden during loading | P1 |

### 6.10 Settings panel

| Requirement | Description | Priority |
|-------------|-------------|----------|
| FR-10.1 | Gear icon in toolbar toggles inline settings (no dropdown/modal) | P0 |
| FR-10.2 | Settings appear between tab bar and note title | P0 |
| FR-10.3 | Escape key closes settings | P1 |
| FR-10.4 | Settings auto-close when note changes | P1 |
| FR-10.5 | Controls: vault browse, subfolders, layout, font size, refresh actions | P0 |

**Settings controls:**

| Control | Behavior |
|---------|----------|
| Browse | Native folder picker for vault |
| Subfolders | Nested accordion with checkboxes |
| Layout | Square (460px) / Rectangle (640px) height |
| Font size | Slider + stepper, 9–16px |
| Refresh now | Pick/refresh without force |
| Regenerate summary | Re-summarize current note, bypass cache |

### 6.11 Menu bar tray

| Requirement | Description | Priority |
|-------------|-------------|----------|
| FR-11.1 | Tray icon with context menu | P0 |
| FR-11.2 | Menu items: Choose folder, Aspect ratio, Force refresh, Refresh now, Open current note, Quit | P0 |
| FR-11.3 | Open current note launches file in default app (typically Obsidian) | P1 |

### 6.12 Toolbar actions

| Requirement | Description | Priority |
|-------------|-------------|----------|
| FR-12.1 | Force refresh button (spinning icon while loading) | P0 |
| FR-12.2 | Settings gear button | P0 |

---

## 7. User Interface Specification

### 7.1 Layout hierarchy

```
┌──────────────────────────────────────┐
│                    [↻] [⚙]          │  ← Toolbar (top-right)
├──────────────────────────────────────┤
│  Summary  │  Original                │  ← Content view tabs
├──────────────────────────────────────┤
│  [Settings panel — when open]        │
├──────────────────────────────────────┤
│  Note Title                          │
├──────────────────────────────────────┤
│                                      │
│  Markdown content area               │  ← Scrollable
│  (summary or original)               │
│                                      │
├──────────────────────────────────────┤
│  ▸ Details  folder · N related       │  ← Summary tab only
├──────────────────────────────────────┤
│  path/to/note.md                     │
│  Refreshes in 2h 14m                 │  ← Footer
└──────────────────────────────────────┘
```

### 7.2 Dimensions

| Aspect ratio | Width | Height |
|--------------|-------|--------|
| Square | 320px | 460px |
| Rectangle | 320px | 640px |

### 7.3 Visual design

| Element | Style |
|---------|-------|
| Card background | `rgba(24, 24, 28, 0.72)` + 18px backdrop blur |
| Border | 1px `rgba(255, 255, 255, 0.22)`, 18px radius |
| Primary text | `#f5f5f7` at 90% opacity |
| Accent (tabs, links, tags) | Purple `#b8afff` / `#c4bbff` |
| Inline code | Orange `#ff9f5a` pill |
| Active tab | Purple text + 2px bottom border |
| Typography | JetBrains Mono for body; system weight for title |

### 7.4 States

| State | UI behavior |
|-------|-------------|
| `needsSetup` | Prompt to choose vault folder |
| `loading` | Loader animation; tabs disabled for Original |
| `ready` | Full content; Details available on Summary tab |
| `error` | Red summary text; error message in payload |

---

## 8. Technical Architecture

### 8.1 Stack

| Layer | Technology |
|-------|------------|
| Runtime | Electron 36 |
| Build | electron-vite 3, Vite 6 |
| UI | React 19, TypeScript 5 |
| Markdown | react-markdown, remark-gfm |
| LLM | Claude CLI (local subprocess) |
| IPC | Electron contextBridge + ipcMain handlers |

### 8.2 Process architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Main process (Node.js)                                      │
│  ├─ RefreshScheduler    — timing, note pick, state machine  │
│  ├─ obsidianScanner     — vault scan, read, hash            │
│  ├─ summaryService      — Claude CLI, cache R/W             │
│  ├─ relatedNotes        — title → file path resolution      │
│  ├─ config              — load/save config.json             │
│  ├─ ipc                 — renderer ↔ main bridge              │
│  └─ WidgetWindow        — BrowserWindow lifecycle           │
├─────────────────────────────────────────────────────────────┤
│ Preload (contextBridge)                                     │
│  └─ window.widgetApi — typed IPC facade                     │
├─────────────────────────────────────────────────────────────┤
│ Renderer (React)                                            │
│  ├─ App                 — layout, tabs, state                 │
│  ├─ MarkdownRenderer    — GFM + Obsidian preprocessing      │
│  ├─ SettingsPanel       — inline configuration              │
│  ├─ NoteSummaryMeta     — details accordion                 │
│  └─ NoteLoader          — loading animation                 │
└─────────────────────────────────────────────────────────────┘
```

### 8.3 Key modules

| Path | Responsibility |
|------|----------------|
| `src/main/scheduler.ts` | Refresh timer, note loading orchestration |
| `src/main/summaryService.ts` | Claude CLI spawn, prompt, parse, cache |
| `src/main/obsidianScanner.ts` | Recursive `.md` discovery, frontmatter strip |
| `src/main/relatedNotes.ts` | Fuzzy title/path lookup for related notes |
| `src/main/config.ts` | Config persistence and normalization |
| `src/main/widgetWindow.ts` | Frameless panel window positioning |
| `src/renderer/obsidianTags.ts` | Wiki link + tag markdown preprocessing |
| `src/shared/types.ts` | Shared types and IPC channel constants |

### 8.4 IPC API (`window.widgetApi`)

| Method | Description |
|--------|-------------|
| `getNote()` | Current `NotePayload` |
| `getSettings()` | Current `WidgetSettings` |
| `updateSettings(partial)` | Persist settings, broadcast update |
| `chooseFolder()` | Native folder picker |
| `refreshNow()` | Scheduled refresh |
| `forceRefresh()` | Force new random note |
| `regenerateSummary()` | Bypass cache for current note |
| `loadNote(filePath)` | Load specific note in-widget |
| `openNote(filePath)` | Open in system default app |
| `onNoteUpdated(cb)` | Subscribe to note changes |
| `onSettingsUpdated(cb)` | Subscribe to settings changes |

### 8.5 LLM prompt contract

**Input:** Note title + body (≤12,000 chars)

**Expected output (JSON only):**
```json
{
  "summary": "2-3 sentence markdown summary.",
  "relatedNotes": [
    { "title": "Exact Note Title" }
  ]
}
```

**Claude CLI flags:** `-p`, `--no-session-persistence`, `--permission-mode dontAsk`, `--output-format text`

---

## 9. Configuration & Persistence

### 9.1 Config file location

```
~/Library/Application Support/obsidian-widget/config.json
```

### 9.2 Config schema

| Key | Type | Default | UI editable |
|-----|------|---------|-------------|
| `vaultFolderPath` | string | (see below) | Yes |
| `includedSubfolders` | string[] | `[]` (all) | Yes |
| `refreshIntervalHours` | number | `4` | No (config file) |
| `aspectRatio` | `"square"` \| `"rectangle"` | `"rectangle"` | Yes |
| `contentView` | `"summary"` \| `"original"` | `"summary"` | Yes (tabs) |
| `fontSizePx` | number (9–16) | `11` | Yes |
| `leftPadding` | number | `16` | No |
| `claudeBinary` | string | `"claude"` | No |
| `summaryCacheDir` | string | `".cache/summaries"` | No |
| `lastPickAt` | ISO string \| null | `null` | Internal |
| `currentFilePath` | string \| null | `null` | Internal |

### 9.3 Summary cache location

```
~/Library/Application Support/obsidian-widget/.cache/summaries/{cacheKey}.json
```

Cache entry shape:
```json
{
  "contentHash": "sha256-hex-of-note-body",
  "summary": "...",
  "relatedNotes": [{ "title": "..." }]
}
```

---

## 10. Dependencies & System Requirements

### 10.1 Requirements

| Requirement | Details |
|-------------|---------|
| OS | macOS (primary target; Electron may run elsewhere untested) |
| Node.js | 18+ for development |
| Claude CLI | Installed and authenticated (`claude` on PATH) |
| Obsidian vault | Local folder of `.md` files (iCloud paths supported) |

### 10.2 Verify Claude CLI

```bash
claude -p "hello"
```

### 10.3 Development commands

```bash
npm install
npm run dev      # Development with hot reload
npm run build    # Production build
npm run start    # Run built app
npm run lint     # ESLint
```

---

## 11. Privacy & Security

| Topic | Approach |
|-------|----------|
| Vault data | Read locally only; never uploaded except to Claude CLI |
| LLM transmission | Note title + body sent to Claude via user's local CLI session |
| API keys | Managed by Claude CLI / user's Anthropic account—not stored in widget |
| Network | No widget-owned network calls; Claude CLI handles its own connectivity |
| IPC | Context isolation enabled; nodeIntegration disabled in renderer |
| File access | Limited to user-selected vault folder and app support directory |

**User implication:** Summarization requires an active Claude CLI subscription and sends note content to Anthropic's models when cache misses occur.

---

## 12. Error Handling

| Scenario | Behavior |
|----------|----------|
| Vault folder missing | `needsSetup` state with setup prompt |
| No markdown files | Error: "No notes found" |
| Claude CLI missing/fails | Error state with CLI error message |
| Claude timeout (120s) | Error with timeout message |
| Unparseable LLM response | Fallback plain-text strip or regenerate prompt |
| Related note title not found | Silently omitted from list |
| Load note while already refreshing | Operation skipped (no queue) |

---

## 13. Success Metrics

| Metric | Target (informal) |
|--------|-------------------|
| Time to first summary | < 30s on cache miss (depends on Claude CLI) |
| Cache hit rate | > 80% after first week of use |
| Widget memory footprint | < 150 MB idle |
| Crash rate | Zero uncaught exceptions in normal operation |
| User comprehension | User can explain core loop without reading docs |

---

## 14. Future Roadmap

### v1.1 — Navigation & polish

- [ ] Clickable wiki links → load note in widget
- [ ] Refresh interval control in settings UI
- [ ] Keyboard shortcuts (e.g. `S`/`O` for tabs, `R` for refresh)
- [ ] README with screenshots and install guide

### v1.2 — Smarter discovery

- [ ] Weight picks by recency, note length, or manual favorites
- [ ] Exclude list / archive folder support
- [ ] "Pinned note" mode (disable random rotation)

### v2.0 — Platform & integrations

- [ ] Optional direct Anthropic API (no CLI dependency)
- [ ] Obsidian URI scheme integration (`obsidian://open?...`)
- [ ] Multiple widget instances / position presets
- [ ] Windows/Linux builds

---

## 15. Open Questions

| # | Question |
|---|----------|
| 1 | Should wiki link clicks navigate in-widget or open Obsidian? |
| 2 | Should refresh interval be exposed in settings or remain config-only? |
| 3 | Distribution: direct `.dmg` release, Homebrew cask, or source-only? |
| 4 | Code signing and notarization for public macOS distribution? |
| 5 | Support alternative LLM backends (OpenAI, local Ollama)? |

---

## 16. Appendix

### A. Default vault path (developer)

```
~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mind
```

### B. Example `config.json`

```json
{
  "vaultFolderPath": "/Users/you/Documents/Obsidian/MyVault",
  "includedSubfolders": ["Projects", "Mind"],
  "refreshIntervalHours": 4,
  "aspectRatio": "rectangle",
  "contentView": "summary",
  "fontSizePx": 11,
  "leftPadding": 16,
  "claudeBinary": "claude",
  "summaryCacheDir": ".cache/summaries",
  "lastPickAt": "2026-06-11T10:30:00.000Z",
  "currentFilePath": "/Users/you/Documents/Obsidian/MyVault/Projects/example.md"
}
```

### C. Wiki link rendering rules

| Input | Display |
|-------|---------|
| `[[Re-conciliation]]` | Re-conciliation (purple text) |
| `[[Folder/Note]]` | Note (basename) |
| `[[Note\|Custom Label]]` | Custom Label |
| `[[Note#Heading]]` | Note (heading stored in link target) |

Tags and wiki links inside `` `code` `` or fenced blocks are left unchanged.

### D. Related note resolution order

1. Exact relative path match (case-insensitive)
2. Note title match (from `# heading` or filename)
3. Basename match (filename without `.md`)

---

*Document maintained alongside the obsidian-widget codebase. For implementation details, refer to source files listed in §8.3.*
