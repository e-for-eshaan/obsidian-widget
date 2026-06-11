#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_APP="${1:-${ROOT_DIR}/macos/build/Release/ObsidianWidgetHost.app}"
APPEX="${HOST_APP}/Contents/PlugIns/ObsidianWidgetExtension.appex"
WIDGET_ID="com.obsidianwidget.app.widget"

if [[ ! -d "${APPEX}" ]]; then
  echo "Widget extension not found at ${APPEX}" >&2
  exit 1
fi

echo "Registering widget extension with PlugInKit…" >&2
pluginkit -a "${APPEX}"
pluginkit -e use -p com.apple.widgetkit-extension -i "${WIDGET_ID}" || true

if pluginkit -m -p com.apple.widgetkit-extension -i "${WIDGET_ID}" -v 2>&1 | rg -q "${WIDGET_ID}"; then
  echo "Widget registered: ${WIDGET_ID}" >&2
else
  cat <<'EOF' >&2
Widget registration did not stick. Try this:

1. Open macos/ObsidianWidget.xcodeproj in Xcode
2. Select the ObsidianWidgetHost scheme
3. Press ⌘R to build and run from Xcode (not Finder)
4. Right-click the app → Open if macOS blocks first launch
5. In the widget gallery, look under "Obsidian Widget" (not "Obsidian Note")
EOF
fi
