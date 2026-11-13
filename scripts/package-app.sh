#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$PROJECT_DIR/dist/Codex Usage.app"

swift build --configuration release --package-path "$PROJECT_DIR"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$PROJECT_DIR/.build/release/CodexUsageMenuBar" \
  "$APP_DIR/Contents/MacOS/CodexUsageMenuBar"
cp "$PROJECT_DIR/Resources/AppInfo.plist" "$APP_DIR/Contents/Info.plist"
chmod +x "$APP_DIR/Contents/MacOS/CodexUsageMenuBar"
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

printf 'Created %s\n' "$APP_DIR"
