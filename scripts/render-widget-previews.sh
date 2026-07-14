#!/bin/zsh

set -euo pipefail

ROOT="${0:A:h:h}"
BUILD_DIR="${TMPDIR:-/tmp}/codex-quota-widget-preview-renderer"

mkdir -p "$BUILD_DIR"

xcrun swiftc \
  -parse-as-library \
  -O \
  -o "$BUILD_DIR/render-widget-previews" \
  "$ROOT/Core/Models.swift" \
  "$ROOT/Core/SharedSnapshotStore.swift" \
  "$ROOT/Core/QuotaVisualTheme.swift" \
  "$ROOT/SharedUI/QuotaThemeRenderer.swift" \
  "$ROOT/scripts/render-widget-previews.swift"

cd "$ROOT"
"$BUILD_DIR/render-widget-previews"
