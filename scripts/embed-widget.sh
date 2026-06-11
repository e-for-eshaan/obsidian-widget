#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MACOS_BUILD_DIR="${ROOT_DIR}/macos/build/Release"
ELECTRON_APP="${1:-${ROOT_DIR}/out/Obsidian Widget-darwin-arm64/Obsidian Widget.app}"

if [[ ! -d "${ELECTRON_APP}" ]]; then
  ELECTRON_APP="${ROOT_DIR}/out/Obsidian Widget-darwin-x64/Obsidian Widget.app"
fi

if [[ ! -d "${ELECTRON_APP}" ]]; then
  ELECTRON_APP="$(find "${ROOT_DIR}/out" -maxdepth 2 -name '*.app' -print -quit 2>/dev/null || true)"
fi

if [[ -z "${ELECTRON_APP}" || ! -d "${ELECTRON_APP}" ]]; then
  echo "Electron app bundle not found. Build Electron first, or pass the .app path as the first argument."
  exit 1
fi

APPEX_SRC="${MACOS_BUILD_DIR}/ObsidianWidgetExtension.appex"
WIDGET_RELOAD_SRC="${MACOS_BUILD_DIR}/WidgetReload"

if [[ ! -d "${APPEX_SRC}" ]]; then
  echo "Widget extension not found at ${APPEX_SRC}. Run scripts/build-macos-widget.sh first."
  exit 1
fi

PLUGINS_DIR="${ELECTRON_APP}/Contents/PlugIns"
RESOURCES_DIR="${ELECTRON_APP}/Contents/Resources"

mkdir -p "${PLUGINS_DIR}" "${RESOURCES_DIR}"

rm -rf "${PLUGINS_DIR}/ObsidianWidgetExtension.appex"
cp -R "${APPEX_SRC}" "${PLUGINS_DIR}/ObsidianWidgetExtension.appex"

if [[ -f "${WIDGET_RELOAD_SRC}" ]]; then
  cp "${WIDGET_RELOAD_SRC}" "${RESOURCES_DIR}/WidgetReload"
  chmod +x "${RESOURCES_DIR}/WidgetReload"
fi

echo "Embedded widget extension into ${ELECTRON_APP}"
