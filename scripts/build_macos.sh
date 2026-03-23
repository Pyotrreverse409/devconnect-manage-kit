#!/bin/bash
set -e

echo "🔨 Building DevConnect for macOS..."

flutter build macos --release

APP_PATH="build/macos/Build/Products/Release/DevConnect.app"
OUTPUT_DIR="dist/macos"
mkdir -p "$OUTPUT_DIR"

# Copy .app bundle
cp -R "$APP_PATH" "$OUTPUT_DIR/"

# Create DMG
echo "📦 Creating DMG..."
DMG_NAME="DevConnect-macOS-v1.0.0.dmg"
hdiutil create -volname "DevConnect" \
  -srcfolder "$OUTPUT_DIR/DevConnect.app" \
  -ov -format UDZO \
  "$OUTPUT_DIR/$DMG_NAME"

echo "✅ Built: $OUTPUT_DIR/$DMG_NAME"
echo "✅ App:   $OUTPUT_DIR/DevConnect.app"
