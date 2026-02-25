#!/bin/bash

# ToneStudio - Reset, Rebuild, and Relaunch Script
# Automates permission reset, clean build, and app launch

set -e

APP_BUNDLE_ID="com.upen.ToneStudio"
PROJECT_DIR="/Users/upendranath.kaki/Desktop/Codes/Mac-ToneStudio/Mac-ToneStudio"
BUILD_DIR="/Users/upendranath.kaki/Library/Developer/Xcode/DerivedData/ToneStudio-dfjyqpoxsxtakufufqcrituirsdz/Build/Products/Debug"
APP_PATH="$BUILD_DIR/ToneStudio.app"

echo "=== ToneStudio Rebuild Script ==="
echo ""

# Step 1: Kill running app
echo "[1/6] Killing existing ToneStudio processes..."
pkill -9 -f "ToneStudio" 2>/dev/null || true
sleep 1

# Step 2: Reset permissions
echo "[2/6] Resetting Accessibility and Input Monitoring permissions..."
tccutil reset Accessibility "$APP_BUNDLE_ID" 2>/dev/null || true
tccutil reset ListenEvent "$APP_BUNDLE_ID" 2>/dev/null || true
echo "       Permissions reset successfully."

# Step 3: Clean and build
echo "[3/6] Building ToneStudio (clean build)..."
cd "$PROJECT_DIR"
xcodebuild -scheme ToneStudio -configuration Debug clean build -quiet 2>&1 | grep -E "(error:|BUILD)" || true

# Check if build succeeded
if [ -d "$APP_PATH" ]; then
    echo "       Build succeeded."
else
    echo "       Build FAILED. Check Xcode for errors."
    exit 1
fi

# Step 4: Launch the app
echo "[4/6] Launching ToneStudio..."
open "$APP_PATH"
sleep 1

# Step 5: Open Finder at the app location and Input Monitoring
echo "[5/6] Opening Input Monitoring + Finder at app location..."
open -R "$APP_PATH"
sleep 0.5
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
sleep 1

# Step 6: Open Accessibility
echo "[6/6] Opening Accessibility preferences..."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    MANUAL STEPS REQUIRED                      ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║ 1. INPUT MONITORING (window should be open):                  ║"
echo "║    - Click the + button at bottom                             ║"
echo "║    - DRAG ToneStudio.app from Finder window that opened       ║"
echo "║    - Or navigate to the Debug folder shown in Finder          ║"
echo "║    - Enable the checkbox for ToneStudio                       ║"
echo "║                                                               ║"
echo "║ 2. ACCESSIBILITY:                                             ║"
echo "║    - ToneStudio should appear - enable it                     ║"
echo "║    - If not, use same drag method as Input Monitoring         ║"
echo "║                                                               ║"
echo "║ 3. After enabling both, select text anywhere to test          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
