#!/bin/bash

# Exit immediately if any command fails
set -e

# Find script directory and repository root
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

echo "=== Preparing DMG Staging Directory ==="
rm -rf "${DIST_DIR}"
mkdir -p "${STAGING_DIR}"

# Copy Lyra.app bundle into staging
cp -R "${ROOT_DIR}/Lyra.app" "${STAGING_DIR}/Lyra.app"

# Create symlink to /Applications for Finder drag-and-drop
ln -s /Applications "${STAGING_DIR}/Applications"

echo "=== Creating Lyra.dmg Disk Image using hdiutil ==="
hdiutil create \
    -volname "Lyra" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

# Clean up staging directory
rm -rf "${STAGING_DIR}"

echo "========================================================="
echo "✨ Lyra.dmg Created Successfully!"
echo "📍 Location: ${DMG_PATH}"
echo "========================================================="
