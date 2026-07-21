#!/bin/bash
# build_backend_android.sh
# Compiles the Go backend binary for Android ARM64 and places it in the assets folder.
# Run this once before `flutter run` when targeting Android.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"
ASSETS_DIR="$SCRIPT_DIR/android/app/src/main/assets/backend"

echo "🔨 Building Go backend for Android..."

mkdir -p "$ASSETS_DIR"

cd "$BACKEND_DIR"

echo "  → arm64-v8a"
GOOS=android GOARCH=arm64 go build \
  -ldflags="-checklinkname=0" \
  -o "$ASSETS_DIR/aniting-backend-arm64" .

# Optionally build x86_64 too (for emulator)
if command -v go &> /dev/null; then
  echo "  → x86_64 (emulator)"
  GOOS=android GOARCH=amd64 go build \
    -ldflags="-checklinkname=0" \
    -o "$ASSETS_DIR/aniting-backend-x86_64" . 2>/dev/null || echo "  ⚠ x86_64 build skipped (optional)"
fi

echo ""
echo "✅ Backend binaries built:"
ls -lh "$ASSETS_DIR"
echo ""
echo "Now run: flutter run"
