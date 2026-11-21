#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building AutoClicker Universal (Apple Silicon + Intel) for macOS Sonoma 14.0+..."

# 1. Generate AppIcon.icns if needed
if [ ! -f "AutoClickerApp/AppIcon.icns" ]; then
    echo "Generating high-resolution macOS application icon..."
    ICON_TMP=$(mktemp -d)
    swift AutoClickerApp/generate_icon.swift "$ICON_TMP/icon_1024.png"
    
    mkdir -p "$ICON_TMP/AppIcon.iconset"
    sips -z 16 16     "$ICON_TMP/icon_1024.png" --out "$ICON_TMP/AppIcon.iconset/icon_16x16.png" > /dev/null
    sips -z 32 32     "$ICON_TMP/icon_1024.png" --out "$ICON_TMP/AppIcon.iconset/icon_16x16@2x.png" > /dev/null
    sips -z 32 32     "$ICON_TMP/icon_1024.png" --out "$ICON_TMP/AppIcon.iconset/icon_32x32.png" > /dev/null
    sips -z 64 64     "$ICON_TMP/icon_1024.png" --out "$ICON_TMP/AppIcon.iconset/icon_32x32@2x.png" > /dev/null
    sips -z 128 128   "$ICON_TMP/icon_1024.png" --out "$ICON_TMP/AppIcon.iconset/icon_128x128.png" > /dev/null
    sips -z 256 256   "$ICON_TMP/icon_1024.png" --out "$ICON_TMP/AppIcon.iconset/icon_128x128@2x.png" > /dev/null
    sips -z 256 256   "$ICON_TMP/icon_1024.png" --out "$ICON_TMP/AppIcon.iconset/icon_256x256.png" > /dev/null
    sips -z 512 512   "$ICON_TMP/icon_1024.png" --out "$ICON_TMP/AppIcon.iconset/icon_256x256@2x.png" > /dev/null
    sips -z 512 512   "$ICON_TMP/icon_1024.png" --out "$ICON_TMP/AppIcon.iconset/icon_512x512.png" > /dev/null
    cp "$ICON_TMP/icon_1024.png" "$ICON_TMP/AppIcon.iconset/icon_512x512@2x.png"
    
    iconutil -c icns "$ICON_TMP/AppIcon.iconset" -o "AutoClickerApp/AppIcon.icns"
    rm -rf "$ICON_TMP"
    echo "AppIcon.icns generated successfully!"
fi

SWIFT_FILES=(
    "AutoClickerApp/Models.swift"
    "AutoClickerApp/InputSimulator.swift"
    "AutoClickerApp/CoordinatePicker.swift"
    "AutoClickerApp/RoutineRunner.swift"
    "AutoClickerApp/RoutineViewModel.swift"
    "AutoClickerApp/StepRowView.swift"
    "AutoClickerApp/ContentView.swift"
    "AutoClickerApp/AutoClickerApp.swift"
)

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Compiling for Apple Silicon (arm64, macOS 14.0+)..."
swiftc -O -parse-as-library -target arm64-apple-macos14.0 "${SWIFT_FILES[@]}" -o "$TMP_DIR/AutoClickerGUI_arm64"

echo "Compiling for Intel (x86_64, macOS 14.0+)..."
swiftc -O -parse-as-library -target x86_64-apple-macos14.0 "${SWIFT_FILES[@]}" -o "$TMP_DIR/AutoClickerGUI_x86"

echo "Packaging Universal binary..."
lipo -create "$TMP_DIR/AutoClickerGUI_arm64" "$TMP_DIR/AutoClickerGUI_x86" -output AutoClickerGUI
chmod +x AutoClickerGUI

# Create .app bundle
APP_DIR="AutoClicker.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp AutoClickerGUI "$APP_DIR/Contents/MacOS/AutoClickerGUI"
cp AutoClickerApp/Info.plist "$APP_DIR/Contents/Info.plist"
cp AutoClickerApp/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
touch "$APP_DIR"

echo "Created macOS Application Bundle with Icon: $APP_DIR"
file AutoClickerGUI
ls -lh AutoClickerGUI
ls -lh "$APP_DIR/Contents/Resources/AppIcon.icns"
