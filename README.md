# Obsidian Widget

A macOS app that surfaces random notes from your Obsidian vault as short AI summaries on a native **WidgetKit desktop widget**. The **ObsidianWidgetHost** SwiftUI app is the primary controller: menu bar tray, note viewer, vault scanning, Claude summarization, and widget sync via App Groups.

**Random note → Claude summary → native desktop widget.**

> **Note:** The Electron menu bar app (`npm run dev`) is **deprecated** and kept only for comparison during migration. Use **ObsidianWidgetHost** in Xcode as your daily driver.

---

## Architecture

```text
ObsidianWidgetHost (SwiftUI)     App Group container           WidgetKit extension
────────────────────────────     ───────────────────           ───────────────────
Vault scan / Claude CLI      →   widget-state.json        →   SwiftUI widget
Menu bar + Note Viewer           team-prefixed group           Title + bullet summary
Scheduler                          .shared                     Tap → open Host app
```

---

## What it does

- Picks a random markdown note from your vault every few hours
- Generates a bullet-point summary using the **Claude CLI**
- Shows the summary on a **native macOS desktop widget**
- Opens a full **Note Viewer** window from the menu bar or widget tap
- Opens the current note in **Obsidian** via the toolbar button
- Caches summaries so unchanged notes are not re-summarized

---

## Requirements

| Requirement | Details |
|-------------|---------|
| **macOS 14+** | Desktop widgets (Sonoma or later) |
| **Xcode 15+** | Required to build and run ObsidianWidgetHost |
| **Obsidian vault** | A local folder of `.md` files (iCloud vault paths work) |
| **Claude CLI** | Installed and logged in — `claude` must work on your PATH |

Verify Claude CLI:

```bash
claude -p "hello"
```

---

## Install & run (recommended — native app)

### One-time Xcode setup

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
open macos/ObsidianWidget.xcodeproj
```

Set your **Development Team** on all 3 targets (ObsidianWidgetHost, ObsidianWidgetExtension, WidgetReload) under Signing & Capabilities.

### Daily development

1. Open `macos/ObsidianWidget.xcodeproj`
2. Select the **ObsidianWidgetHost** scheme (not ObsidianWidgetExtension)
3. Press **⌘R** to run

The app appears in the menu bar. Use **Open Note Viewer…** for the full UI, or tap the desktop widget to open the viewer.

### Add the desktop widget

1. Open **System Settings → Desktop & Dock → Widgets** (or right-click the desktop → **Edit Widgets**)
2. Find **Obsidian Note** and add it to your desktop
3. The widget updates when the host app picks or summarizes a note

**Widget tap** opens the native Note Viewer (`obsidianwidget://open`). Use the **◇ Open in Obsidian** toolbar button to open the note in Obsidian.

---

## Using the app

### Native desktop widget

| Action | What it does |
|--------|--------------|
| **Glance** | Shows note title + bullet summary |
| **Tap** | Opens the Obsidian Widget Note Viewer |

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
- Open current note in Obsidian
- Quit

### Exploring notes (Note Viewer)

- **Related notes** — pills under the summary; click to load that note
- **Wiki links** — `[[Note Title]]` links in the original view are clickable
- **Back button** — appears when you navigate via links or related notes

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
6. The current note state is written to the App Group and the widget timeline is reloaded via the **WidgetReload** helper.

Summaries only run when needed—editing a note invalidates its cache for that file.

---

## Configuration

Settings are saved automatically to:

```text
~/Library/Application Support/obsidian-widget/config.json
```

This path is shared with the legacy Electron app, so existing settings carry over.

Advanced options (edit manually while the app is quit):

| Key | Default | Description |
|-----|---------|-------------|
| `refreshIntervalHours` | `4` | Hours between automatic note picks |
| `claudeBinary` | `"claude"` | Path to Claude CLI if not on PATH |

See `config.example.json` for a full example.

---

## App Group & signing

Both the host app and WidgetKit extension use App Group **`group.com.obsidianwidget.shared`** (team-prefixed at runtime, e.g. `4S3YY47BGX.group.com.obsidianwidget.shared`).

For local development:

1. Set your Personal Team on all 3 Xcode targets
2. Run **ObsidianWidgetHost** — it writes widget state and embeds the extension

---

## Legacy Electron app (deprecated)

The Electron controller is no longer required for normal use.

```bash
npm install
npm run dev    # deprecated — menu bar + React note viewer
```

Full Electron + embedded widget pipeline (optional):

```bash
npm run build:all
```

---

## Development

```bash
# Native (primary)
open macos/ObsidianWidget.xcodeproj   # ⌘R on ObsidianWidgetHost scheme

# Legacy Electron
npm run dev
npm run build
npm run build:macos-widget
npm run embed:widget
npm run build:all
npm run lint
```

Stack: SwiftUI, WidgetKit, App Groups, Claude CLI. Legacy stack: Electron, React, TypeScript.

Native sources live under [`macos/`](macos/).

---

## Limitations

- **macOS 14+ only** (desktop widgets)
- Requires **Xcode** to build and run the native host app
- Requires **Claude CLI** (no built-in API key UI)
- **Read-only** — notes cannot be edited in the app
- Refresh interval is config-file only (not in settings UI yet)
- Widget shows summary only; full navigation lives in the Note Viewer
- Markdown rendering in the native viewer is SwiftUI-based (basic GFM subset, not full Obsidian parity)

---

## License

No license specified yet. Use and modify at your own discretion until one is added.
