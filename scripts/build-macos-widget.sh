#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MACOS_DIR="${ROOT_DIR}/macos"
BUILD_DIR="${MACOS_DIR}/build"
PROJECT="${MACOS_DIR}/ObsidianWidget.xcodeproj"
XCODE_APP="/Applications/Xcode.app"

if [[ ! -x "${XCODE_APP}/Contents/Developer/usr/bin/xcodebuild" ]]; then
  cat <<'EOF' >&2
Error: full Xcode is required to build the WidgetKit extension.

Command Line Tools alone are not enough for xcodebuild + WidgetKit.

Install Xcode:
  1. Open the Mac App Store and install "Xcode"
  2. Open Xcode once and accept the license
  3. Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  4. Retry: npm run build:macos-widget

Electron-only development still works without Xcode:
  npm run dev
  npm run build
EOF
  exit 1
fi

if [[ "$(xcode-select -p)" != "${XCODE_APP}/Contents/Developer" ]]; then
  cat <<EOF >&2
Error: Xcode is installed but not selected as the active developer directory.

Run:
  sudo xcode-select -s ${XCODE_APP}/Contents/Developer

Then retry: npm run build:macos-widget
EOF
  exit 1
fi

XCODEBUILD="${XCODE_APP}/Contents/Developer/usr/bin/xcodebuild"

echo "Running Xcode first-launch setup (installs CoreSimulator etc.)…" >&2
"${XCODEBUILD}" -runFirstLaunch

mkdir -p "${BUILD_DIR}"

build_native() {
  if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
    "${XCODEBUILD}" \
      -project "${PROJECT}" \
      "$@" \
      -configuration Release \
      DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
      SYMROOT="${BUILD_DIR}" \
      OBJROOT="${BUILD_DIR}/Intermediates" \
      build
    return
  fi

  "${XCODEBUILD}" \
    -project "${PROJECT}" \
    "$@" \
    -configuration Release \
    SYMROOT="${BUILD_DIR}" \
    OBJROOT="${BUILD_DIR}/Intermediates" \
    build
}

if ! build_native -target ObsidianWidgetHost -target ObsidianWidgetExtension; then
  cat <<'EOF' >&2

Build failed. If the error mentions signing or entitlements:

  1. Open macos/ObsidianWidget.xcodeproj in Xcode
  2. Select each target (ObsidianWidgetHost, ObsidianWidgetExtension, WidgetReload)
  3. Signing & Capabilities → Team → choose your Apple ID team
  4. Retry with your team ID:

     DEVELOPMENT_TEAM=YOUR_TEAM_ID npm run build:macos-widget

Find your team ID in Xcode (Signing settings) or at https://developer.apple.com/account
EOF
  exit 1
fi

build_native -target WidgetReload

echo "Built native artifacts in ${BUILD_DIR}/Release"

bash "${ROOT_DIR}/scripts/register-widget.sh" "${BUILD_DIR}/Release/ObsidianWidgetHost.app"
