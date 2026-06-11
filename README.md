# Obsidian Widget

A macOS desktop widget that surfaces random notes from your Obsidian vault as short AI summaries. It sits on the left edge of your screen, always on top, and rotates through your notes on a schedule—so old ideas resurface without opening Obsidian.

**Random note → Claude summary → glanceable widget on your desktop.**

---

## What it does

- Picks a random markdown note from your vault every few hours
- Generates a bullet-point summary using the **Claude CLI**
- Shows the full original note when you want to read more
- Lets you follow **wiki links** and **related notes** inside the widget
- Opens the current note in **Obsidian** with one click
- Caches summaries so unchanged notes are not re-summarized

---

## Requirements

| Requirement | Details |
|-------------|---------|
| **macOS** | Primary target (Electron app) |
| **Obsidian vault** | A local folder of `.md` files (iCloud vault paths work) |
| **Claude CLI** | Installed and logged in — `claude` must work on your PATH |
| **Node.js 18+** | Only needed if building from source |

Verify Claude CLI:

```bash
claude -p "hello"
```

---

## Install & run

### From source

```bash
git clone https://github.com/e-for-eshaan/obsidian-widget.git
cd obsidian-widget
npm install
npm run dev
```

Production build:

```bash
npm run build
npm run start
```

On first launch, choose your Obsidian vault folder in **Settings** (gear icon) or from the menu bar tray.

---

## Using the widget

### Main controls

| Control | What it does |
|---------|--------------|
| **Summary / Original tabs** | Switch between AI summary and full note |
| **↻ Refresh** | Pick a new random note immediately |
| **◇ Open in Obsidian** | Open the current note in Obsidian |
| **⚙ Settings** | Vault, subfolders, layout, font size, refresh actions |

### Menu bar tray

Right-click the tray icon for:

- Choose vault folder
- Square / rectangle layout
- Refresh now / force refresh
- Open current note
- Quit

### Exploring notes

- **Related notes** — pills under the summary; click to load that note in the widget
- **Wiki links** — `[[Note Title]]` links in the original view are clickable
- **Back button** — appears when you navigate via links or related notes; right-click for “Back to top”

### Settings

- **Vault folder** — which Obsidian vault to read from
- **Subfolders** — limit random picks to specific folders (empty = all)
- **Layout** — square (460px) or rectangle (640px) height
- **Font size** — 9–16px for note text
- **Refresh now** — re-run pick logic on schedule rules
- **Regenerate summary** — re-summarize the current note (bypasses cache)

---

## How summarization works

1. The app reads a note from your vault locally.
2. If the note has not changed since last time, it uses the cached summary.
3. Otherwise it sends the title and body (up to ~12k characters) to **Claude CLI** in headless mode.
4. Claude returns a JSON response with a short bullet summary and suggested related note titles.
5. Summaries are stored in `~/Library/Application Support/obsidian-widget/.cache/summaries/`.

Summaries only run when needed—editing a note invalidates its cache for that file.

---

## Configuration

Settings changed in the UI are saved automatically to:

```
~/Library/Application Support/obsidian-widget/config.json
```

Advanced options (edit manually while the app is quit):

| Key | Default | Description |
|-----|---------|-------------|
| `refreshIntervalHours` | `4` | Hours between automatic note picks |
| `claudeBinary` | `"claude"` | Path to Claude CLI if not on PATH |
| `leftPadding` | `16` | Distance from left screen edge (px) |

See `config.example.json` for a full example.

---

## Markdown support

The widget renders Obsidian-style markdown:

- **GFM** — headings, lists, tables, task lists, blockquotes
- **`#tags`** — purple pills
- **`[[Wiki links]]`** — purple, clickable (supports `\|alias` and `#heading`)
- **Inline code** — orange pills
- **Fenced code blocks** — syntax highlighted (VS Code Dark+ theme)

---

## Privacy

- Your vault is read **locally** on your Mac.
- Note content is sent to **Anthropic via your Claude CLI session** only when a summary is generated (cache miss).
- The widget does not store API keys or make its own network requests.
- You need an active Claude CLI / Anthropic account for summarization.

---

## Development

```bash
npm run dev      # Hot reload
npm run build    # Production build
npm run start    # Run built app
npm run lint     # ESLint
```

Stack: Electron, React, TypeScript, react-markdown, Claude CLI.

---

## Limitations

- **macOS only** for now
- Requires **Claude CLI** (no built-in API key UI)
- **Read-only** — notes cannot be edited in the widget
- Refresh interval is config-file only (not in settings UI yet)

---

## License

No license specified yet. Use and modify at your own discretion until one is added.

---

## Related

- Full product spec: [PRD.md](./PRD.md)
