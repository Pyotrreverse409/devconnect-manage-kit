#!/bin/bash
set -e

echo "🔨 Building DevConnect for Windows..."

flutter build windows --release

OUTPUT_DIR="dist/windows"
mkdir -p "$OUTPUT_DIR"

# Copy entire release folder
cp -R "build/windows/x64/runner/Release/." "$OUTPUT_DIR/"

echo "✅ Built: $OUTPUT_DIR/devconnect.exe"
echo ""
echo "To create installer, use Inno Setup or MSIX packaging."
echo "The entire $OUTPUT_DIR folder is the distributable."
