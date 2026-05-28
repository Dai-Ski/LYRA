#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=== Building Lyra in Release Configuration ==="
swift build -c release

echo "=== Creating Lyra.app Bundle ==="
APP_DIR="Lyra.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

# Recreate directories
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"

# Copy release binary
cp ".build/release/Lyra" "${MACOS_DIR}/Lyra"
chmod +x "${MACOS_DIR}/Lyra"
