#!/bin/zsh

set -euo pipefail

ROOT="${0:A:h:h}"
BUILD_DIR="${TMPDIR:-/tmp}/codex-quota-theme-asset-renderer"

mkdir -p "$BUILD_DIR"

xcrun swiftc \
  -parse-as-library \
  -O \
  -o "$BUILD_DIR/render-theme-assets" \
  "$ROOT/Core/Models.swift" \
  "$ROOT/Core/SharedSnapshotStore.swift" \
  "$ROOT/Core/QuotaVisualTheme.swift" \
  "$ROOT/SharedUI/QuotaThemeRenderer.swift" \
  "$ROOT/scripts/render-theme-assets.swift"

cd "$ROOT"
"$BUILD_DIR/render-theme-assets"
