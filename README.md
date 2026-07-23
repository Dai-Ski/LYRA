# Lyra 🎵

Lyra is a lightweight macOS menu bar application that displays real-time, synchronized scrolling lyrics for the track currently playing in Spotify or Apple Music.

[![Download Lyra.dmg](https://img.shields.io/badge/Download-Lyra.dmg%20(macOS)-blue?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/Dai-Ski/LYRA/releases/latest/download/Lyra.dmg)
[![GitHub Release](https://img.shields.io/github/v/release/Dai-Ski/LYRA?style=for-the-badge&color=brightgreen)](https://github.com/Dai-Ski/LYRA/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

For quick answers to common questions, check out the [FAQ](FAQ.md).

---

## Features ✨

- 🎤 **Real-Time Synchronized Lyrics**: Displays live scrolling lyrics in your macOS menu bar, matching playback to the exact second.
- 🔤 **Persistent Romanized Lyrics**: Switch to Romanized mode for Japanese, Korean, Hindi, or non-Latin tracks. Your selection **stays active across all tracks** for the entire session until Lyra is quit.
- ⚡ **Precision Auto-Sync & Latency Compensation**:
  - Advanced regex LRC parser supporting subsecond timestamps (`.xx`, `.xxx`, `:xx`), multiple timestamps per line, and `[offset: ms]` header tags.
  - Duration-scored lyric searching that automatically selects exact studio versions over live cuts or alternate edits.
  - Sub-millisecond AppleScript IPC latency compensation for drift-free playback tracking.
  - Smart dynamic line chunking that advances text naturally during active singing and holds the final phrase during inter-line breaks.
- 🎨 **Custom App & Menu Bar Icons**: Features a custom lyre emblem designed specifically for macOS Light and Dark menu bar modes.
- 🎈 **Interactive Drag & Drop Installer**: Open `Lyra.dmg` to experience an interactive installer window where **musical note emojis (`🎵`, `🎶`, `🎼`, `✨`) pop up continuously** as you drag `Lyra.app` into Applications!

---

## Menu Bar Preview

![Lyra Preview](Assets/preview.png)

---

## Installation 🚀

### Method 1: One-Click DMG Download (Recommended)

1. **[Download Lyra.dmg](https://github.com/Dai-Ski/LYRA/releases/latest/download/Lyra.dmg)** from the latest GitHub Release.
2. Double-click **`Lyra.dmg`** to open the installer window.
3. Drag **Lyra.app** into the **Applications** folder *(enjoy the popping musical note emoji particle animations as you drag!)*.
4. Launch **Lyra** from `/Applications` and click **GRANT PERMISSIONS & START** to allow controlling Spotify / Apple Music metadata.

> [!NOTE]
> Once setup is completed, Lyra runs silently in your menu bar whenever Spotify or Apple Music is active, and hides automatically when music playback stops.

---

### Method 2: Build & Package from Source

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Dai-Ski/LYRA.git
   cd LYRA
   ```
2. **Build Release & Packaging:**
   ```bash
   ./Scripts/create_dmg.sh
   ```
   This compiles the binary in release mode, generates `Lyra.app`, and packages `dist/Lyra.dmg`.
3. **Move to Applications:**
   ```bash
   mv Lyra.app /Applications/
   ```

---

## Romanized Lyrics Mode 🔤

Lyra includes built-in transliteration for non-Latin scripts (such as Japanese, Korean, and Hindi).

1. Click on the **Lyra** menu bar item.
2. Select **Romanized Lyrics** from the menu.
3. **Persistent Session Preference**: Once Romanized mode is selected, Lyra keeps Romanized mode active for all subsequent songs until you quit Lyra. If a song has no romanization (e.g. standard English lyrics), Lyra smoothly displays the original lyrics while keeping your Romanized preference intact for the next track.

---

## Uninstall 🗑️

### To Uninstall the macOS App Bundle

1. Click on the Lyra menu bar icon and select **Quit Lyra**.
2. Open your `/Applications/` folder and move **Lyra.app** to the Trash (or run `rm -rf /Applications/Lyra.app`).
3. Remove from Login Items:
   - Open **System Settings > General > Login Items & Extensions**.
   - Under **Open at Login**, locate **Lyra** and click the `-` button (or toggle it off).

### To Uninstall the CLI Binary (if installed via CLI)

1. Terminate any active background instances:
   ```bash
   killall Lyra
   ```
2. Remove the binary:
   ```bash
   sudo rm /usr/local/bin/lyra
   ```

---

## License

This project is licensed under the [MIT License](LICENSE).
