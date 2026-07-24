#!/bin/bash

# Exit immediately if any command fails
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

echo "========================================="
echo "🎵 Packaging Lyra & Building Lyra.dmg 🎵"
echo "========================================="

# 1. Run app packaging script
bash "${SCRIPT_DIR}/package.sh"

# 2. Prepare DMG Staging Directory
DIST_DIR="${ROOT_DIR}/dist"
STAGING_DIR="${DIST_DIR}/dmg_staging"
DMG_PATH="${DIST_DIR}/Lyra.dmg"
TEMP_DMG="${DIST_DIR}/temp.dmg"

echo "=== Preparing DMG Staging Directory ==="
rm -rf "${DIST_DIR}"
mkdir -p "${STAGING_DIR}"

# Copy Lyra.app bundle into staging
cp -R "${ROOT_DIR}/Lyra.app" "${STAGING_DIR}/Lyra.app"

# Clean extended attributes and re-sign ad-hoc
xattr -cr "${STAGING_DIR}/Lyra.app"
codesign --force --deep --options runtime --sign - "${STAGING_DIR}/Lyra.app"

# Create symlink to /Applications for Finder drag-and-drop
ln -s /Applications "${STAGING_DIR}/Applications"

# Copy cloudy background with glittering emojis into hidden .background folder
if [ -f "${ROOT_DIR}/Assets/dmg_background.png" ]; then
    mkdir -p "${STAGING_DIR}/.background"
    cp "${ROOT_DIR}/Assets/dmg_background.png" "${STAGING_DIR}/.background/background.png"
fi

echo "=== Creating Read/Write Temporary DMG ==="
hdiutil create \
    -volname "Lyra" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDRW \
    "${TEMP_DMG}"

# Mount temporary DMG
echo "=== Mounting Temporary DMG for Finder Window Layout Customization ==="
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "${TEMP_DMG}" | grep -E '/Volumes/' | awk '{print $3}')

if [ -n "$MOUNT_DIR" ]; then
    echo "Mounted at: ${MOUNT_DIR}"
    
    # Configure Finder window layout and background picture using AppleScript
    echo "=== Applying AppleScript Finder Cloudy Background & 128px Icon Size ==="
    osascript -e "
    tell application \"Finder\"
        tell disk \"Lyra\"
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {400, 100, 940, 460}
            set theViewOptions to the icon view options of container window
            set icon size of theViewOptions to 128
            set arrangement of theViewOptions to not arranged
            try
                set background picture of theViewOptions to file \".background:background.png\"
            end try
            set position of item \"Lyra.app\" of container window to {140, 180}
            set position of item \"Applications\" of container window to {400, 180}
            update without registering applications
            delay 1
            close
        end tell
    end tell
    " || true
    
    sync
    hdiutil detach "${MOUNT_DIR}" -force || true
    sleep 5
fi

echo "=== Converting to Compressed Final Lyra.dmg ==="
hdiutil convert "${TEMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG_PATH}" -ov
rm -f "${TEMP_DMG}"
rm -rf "${STAGING_DIR}"

echo "========================================================="
echo "✨ Lyra.dmg Created Successfully with Cloudy Background & Glittering Emojis!"
echo "📍 Location: ${DMG_PATH}"
echo "========================================================="
