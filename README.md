# Lyra 🎵

Lyra is a lightweight macOS menu bar application that displays real-time, synchronized scrolling lyrics for the track currently playing in Spotify or Apple Music.

<p align="center">
  <a href="https://github.com/Dai-Ski/LYRA/releases/download/v1.0.0/Lyra.dmg">
    <img src="https://img.shields.io/badge/Download-Lyra.dmg%20(macOS)-blue?style=for-the-badge&logo=apple&logoColor=white" alt="Download Lyra.dmg" height="48">
  </a>
  <br>
  <sub>Or visit the <a href="https://github.com/Dai-Ski/LYRA/releases">GitHub Releases Page</a></sub>
</p>

---

## Installation 🚀

Installing Lyra is as simple as 1-2-3:

1. **[Click here to Download Lyra.dmg](https://github.com/Dai-Ski/LYRA/releases/download/v1.0.0/Lyra.dmg)** *(or from [GitHub Releases](https://github.com/Dai-Ski/LYRA/releases))*.
2. Open **`Lyra.dmg`** and drag **Lyra** into your **Applications** folder *(musical note emojis will pop up continuously as you drag!)*.
3. Open **Lyra** from your Applications folder and click **GRANT PERMISSIONS & START**.

> [!IMPORTANT]
> **If macOS displays *"Apple could not verify Lyra is free of malware..."***:  
> Because Lyra is an open-source app not distributed via the Mac App Store, macOS Gatekeeper shows a standard security notice on first launch.
> 
> **How to open Lyra on first launch (choose any option below)**:
> - **Option A (System Settings)**: Go to **System Settings → Privacy & Security**, scroll down to *Security*, and click **Open Anyway**.
> - **Option B (Right-Click)**: **Right-click** (or Control-click) **Lyra.app** in `/Applications` → select **Open** → click **Open**.
> - **Option C (Terminal)**: Run `xattr -cr /Applications/Lyra.app` in Terminal.

> [!NOTE]
> Once setup is completed, Lyra runs silently in your top menu bar whenever Spotify or Apple Music is playing, and automatically hides when music stops.

---

## Features ✨

- 🎤 **Real-Time Synchronized Lyrics**: Displays live scrolling lyrics in your macOS menu bar, matching playback to the exact second.
- 🔤 **Persistent Romanized Lyrics**: Switch to Romanized mode for Japanese, Korean, Hindi, or non-Latin tracks. Your selection **stays active across all tracks** until Lyra is quit.
- ⚡ **Precision Auto-Sync**: Automatically handles subsecond timestamps, studio vs live track matching, and latency compensation for drift-free scrolling.
- 🎨 **Custom Menu Bar Emblem**: Designed specifically for macOS Light and Dark mode menu bars.
- 🎈 **Interactive Drag & Drop Installer**: Enjoy floating musical note particle animations when installing from the DMG!

---

## Menu Bar Preview

![Lyra Preview](Assets/preview.png)

---

## Romanized Lyrics Mode 🔤

1. Click the **Lyra** icon in your menu bar.
2. Select **Romanized Lyrics**.
3. Your choice stays saved for the entire session! If a song is in English, Lyra displays original lyrics, then automatically shows Romanized lyrics for non-Latin songs.

---

## How to Uninstall 🗑️

1. Click the **Lyra** menu bar icon and select **Quit Lyra**.
2. Open your **Applications** folder and move **Lyra** to the Trash.
3. Remove from Login Items:
   - Go to **System Settings > General > Login Items & Extensions**.
   - Under **Open at Login**, select **Lyra** and remove it.

---

## License

This project is licensed under the [MIT License](LICENSE).
