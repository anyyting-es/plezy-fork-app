#!/bin/bash
# Build script for torrent backend
# Usage: ./build-torrent-backend.sh [windows|linux|macos|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/torrent-backend"
BUILD_DIR="$SCRIPT_DIR/build/torrent-backend"

cd "$BACKEND_DIR"

# Download dependencies
echo "Downloading Go dependencies..."
go mod download

# Build for specified platform(s)
build_platform() {
    local os=$1
    local arch=$2
    local ext=""
    
    if [ "$os" = "windows" ]; then
        ext=".exe"
    fi
    
    echo "Building for $os/$arch..."
    GOOS=$os GOARCH=$arch go build -o "$BUILD_DIR/$os-$arch/torrent-backend$ext" .
    echo "Built: $BUILD_DIR/$os-$arch/torrent-backend$ext"
}

case "${1:-all}" in
    windows)
        build_platform windows amd64
        ;;
    linux)
        build_platform linux amd64
        ;;
    macos)
        build_platform darwin amd64
        build_platform darwin arm64
        ;;
    all)
        build_platform windows amd64
        build_platform linux amd64
        build_platform darwin amd64
        build_platform darwin arm64
        ;;
    *)
        echo "Usage: $0 [windows|linux|macos|all]"
        exit 1
        ;;
esac

echo "Build complete!"
