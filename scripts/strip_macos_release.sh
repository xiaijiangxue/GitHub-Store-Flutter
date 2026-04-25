#!/bin/bash
# Flutter macOS Release 构建后体积优化脚本
# 自动 strip 框架中的调试符号，通常可减少 30-50% 体积
#
# 使用方法:
#   flutter build macos --release
#   bash scripts/strip_macos_release.sh
#
# 或配合 GitHub Actions 自动执行

set -e

APP_PATH="build/macos/Build/Products/Release/github_store_flutter.app"
FRAMEWORKS_PATH="$APP_PATH/Contents/Frameworks"

if [ ! -d "$FRAMEWORKS_PATH" ]; then
    echo "Not found: $FRAMEWORKS_PATH"
    echo "Please run first: flutter build macos --release"
    exit 1
fi

echo "=== macOS Release Size Optimization ==="
echo ""

BEFORE_SIZE=$(du -sh "$APP_PATH" | cut -f1)
echo "Before: $BEFORE_SIZE"
echo ""

cd "$FRAMEWORKS_PATH"

# Strip all .framework debug symbols
for framework in *.framework; do
    if [ -d "$framework" ]; then
        BINARY_NAME="${framework%.framework}"
        BINARY_PATH="$framework/$BINARY_NAME"

        if [ -f "$BINARY_PATH" ]; then
            echo "Stripping: $framework"
            strip -x -S "$BINARY_PATH" 2>/dev/null || true
        fi
    fi
done

# Strip all .dylib
for dylib in *.dylib; do
    if [ -f "$dylib" ]; then
        echo "Stripping: $dylib"
        strip -x -S "$dylib" 2>/dev/null || true
    fi
done

cd -

# Remove dSYM files
echo ""
echo "Cleaning dSYM files..."
find "$APP_PATH" -name "*.dSYM" -type d -exec rm -rf {} + 2>/dev/null || true

# Remove temp files
echo "Cleaning temp files..."
find "$APP_PATH" -name "*.xcconfig" -delete 2>/dev/null || true
find "$APP_PATH" -name "ephemeral" -type d -exec rm -rf {} + 2>/dev/null || true

AFTER_SIZE=$(du -sh "$APP_PATH" | cut -f1)
echo ""
echo "=== Done ==="
echo "Before: $BEFORE_SIZE"
echo "After:  $AFTER_SIZE"
echo ""

echo "=== Framework Size Details ==="
du -sh "$FRAMEWORKS_PATH"/* 2>/dev/null | sort -rh | head -10
