# Obsidian Widget

A macOS menu bar app that surfaces random notes from your Obsidian vault as short AI summaries on a native **WidgetKit desktop widget**. An Electron controller handles vault scanning, Claude summarization, and a full note viewer; a SwiftUI widget extension reads shared state via App Groups.

**Random note → Claude summary → native desktop widget.**

---

## Architecture

```text
Electron (menu bar)          App Group container           WidgetKit extension
───────────────────          ───────────────────           ───────────────────
Vault scan / Claude CLI  →   widget-state.json        →   SwiftUI widget
Scheduler / tray menu        group.com.obsidianwidget    Title + bullet summary
Note viewer window           .shared                     Tap → open in Obsidian
```

---

## What it does

- Picks a random markdown note from your vault every few hours
- Generates a bullet-point summary using the **Claude CLI**
- Shows the summary on a **native macOS desktop widget**
- Opens a full **Note Viewer** window from the menu bar for original text, wiki links, and settings
- Opens the current note in **Obsidian** from the widget tap or viewer
- Caches summaries so unchanged notes are not re-summarized

---

## Requirements

| Requirement | Details |
|-------------|---------|
| **macOS 14+** | Desktop widgets (Sonoma or later) |
| **Xcode 15+** | Required to build the native WidgetKit extension (App Store install; Command Line Tools alone are not enough) |
| **Obsidian vault** | A local folder of `.md` files (iCloud vault paths work) |
| **Claude CLI** | Installed and logged in — `claude` must work on your PATH |
| **Node.js 18+** | For building the Electron app from source |

Verify Claude CLI:

```bash
claude -p "hello"
```

---

## Install & run

### From source (Electron only)

```bash
git clone https://github.com/e-for-eshaan/obsidian-widget.git
cd obsidian-widget
npm install
npm run dev
```

The menu bar app runs in the background. Use **Open Note Viewer…** from the tray for the full UI.

### Full build (Electron + native widget)

Requires **full Xcode** from the Mac App Store (not just Command Line Tools):

```bash
# One-time Xcode setup
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch          # installs CoreSimulator and other components

# Signing (required for App Groups)
open macos/ObsidianWidget.xcodeproj # set Team on all 3 targets in Signing & Capabilities

npm install
npm run build:all
# or with team ID:
# DEVELOPMENT_TEAM=YOUR_TEAM_ID npm run build:all
```

Or step by step:

```bash
npm run build                 # Electron app
npm run build:macos-widget      # WidgetKit extension + WidgetReload helper
npm run embed:widget            # Copy .appex into Electron .app bundle
```

On first launch, choose your Obsidian vault folder in **Settings** (gear icon) or from the menu bar tray.

### Add the desktop widget

1. Open **System Settings → Desktop & Dock → Widgets** (or right-click the desktop → **Edit Widgets**)
2. Find **Obsidian Note** and add it to your desktop
3. The widget updates when the menu bar app picks or summarizes a note

Tap the widget to open the current note in Obsidian.

---

## Using the app

### Native desktop widget

| Action | What it does |
|--------|--------------|
| **Glance** | Shows note title + bullet summary |
| **Tap** | Opens the current note in Obsidian |

### Note Viewer (menu bar → Open Note Viewer…)

| Control | What it does |
|---------|--------------|
| **Summary / Original tabs** | Switch between AI summary and full note |
| **↻ Refresh** | Pick a new random note immediately |
| **◇ Open in Obsidian** | Open the current note in Obsidian |
| **⚙ Settings** | Vault, subfolders, font size, refresh actions |

### Menu bar tray

Right-click the tray icon for:

- Open Note Viewer…
- Choose vault folder
- Refresh now / force refresh
- Open current note
- Quit

### Exploring notes (Note Viewer)

- **Related notes** — pills under the summary; click to load that note
- **Wiki links** — `[[Note Title]]` links in the original view are clickable
- **Back button** — appears when you navigate via links or related notes; right-click for “Back to top”

### Settings

- **Vault folder** — which Obsidian vault to read from
- **Subfolders** — limit random picks to specific folders (empty = all)
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
6. The current note state is written to the App Group at `~/Library/Group Containers/group.com.obsidianwidget.shared/widget-state.json` and the widget timeline is reloaded.

Summaries only run when needed—editing a note invalidates its cache for that file.

---

## Configuration

Settings changed in the UI are saved automatically to:

```text
~/Library/Application Support/obsidian-widget/config.json
```

Advanced options (edit manually while the app is quit):

| Key | Default | Description |
|-----|---------|-------------|
| `refreshIntervalHours` | `4` | Hours between automatic note picks |
| `claudeBinary` | `"claude"` | Path to Claude CLI if not on PATH |

See `config.example.json` for a full example.

---

## App Group & signing

Both the Electron app and WidgetKit extension use App Group **`group.com.obsidianwidget.shared`**.

For local development, the Electron app writes directly to the group container path. For distribution:

1. Register the App Group in the Apple Developer portal
2. Sign the Electron app with [`macos/ObsidianWidget.entitlements`](macos/ObsidianWidget.entitlements)
3. Sign the embedded widget extension (built from [`macos/ObsidianWidget.xcodeproj`](macos/ObsidianWidget.xcodeproj))

The Xcode project also includes a minimal **ObsidianWidgetHost** app for developing the widget extension standalone.

---

## Markdown support (Note Viewer)

The viewer renders Obsidian-style markdown:

- **GFM** — headings, lists, tables, task lists, blockquotes
- **`#tags`** — purple pills
- **`[[Wiki links]]`** — purple, clickable (supports `\|alias` and `#heading`)
- **Inline code** — orange pills
- **Fenced code blocks** — syntax highlighted (VS Code Dark+ theme)

---

## Privacy

- Your vault is read **locally** on your Mac.
- Note content is sent to **Anthropic via your Claude CLI session** only when a summary is generated (cache miss).
- The app does not store API keys or make its own network requests.
- You need an active Claude CLI / Anthropic account for summarization.

---

## Development

```bash
npm run dev              # Electron hot reload (menu bar + note viewer)
npm run build            # Production Electron build
npm run build:macos-widget   # Xcode: widget extension + reload helper
npm run embed:widget     # Embed .appex into Electron .app
npm run build:all        # Full pipeline
npm run lint             # ESLint
```

Stack: Electron, React, TypeScript, SwiftUI WidgetKit, App Groups, Claude CLI.

Native sources live under [`macos/`](macos/).

---

## Limitations

- **macOS 14+ only** (desktop widgets)
- Requires **Xcode** to build the native widget extension
- Requires **Claude CLI** (no built-in API key UI)
- **Read-only** — notes cannot be edited in the app
- Refresh interval is config-file only (not in settings UI yet)
- Widget shows summary only; full navigation lives in the Note Viewer

---

## License

No license specified yet. Use and modify at your own discretion until one is added.
