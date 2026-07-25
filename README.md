# Lyra 🎵

<p align="center">
  <img src="docs/index.html" alt="Lyra Emblem" width="120" style="border-radius: 20px;">
  <h3 align="center">Real-Time Synchronized Lyrics for macOS</h3>
  <p align="center">
    A lightweight, elegant macOS menu bar app that displays real-time, synchronized scrolling lyrics for Spotify & Apple Music.
    <br />
    <a href="https://dai-ski.github.io/LYRA/"><strong>Explore Landing Page »</strong></a>
    <br />
    <br />
    <a href="https://dai-ski.github.io/LYRA/">
      <img src="https://img.shields.io/badge/Download-Lyra.dmg%20(macOS)-0071e3?style=for-the-badge&logo=apple&logoColor=white" alt="Download Lyra.dmg" height="46">
    </a>
  </p>
</p>

<p align="center">
  <a href="https://github.com/Dai-Ski/LYRA/releases"><img src="https://img.shields.io/github/v/release/Dai-Ski/LYRA?color=0071e3&label=Release" alt="Latest Release"></a>
  <a href="https://github.com/Dai-Ski/LYRA/stargazers"><img src="https://img.shields.io/github/stars/Dai-Ski/LYRA?color=ff9800&label=%E2%AD%90%20Stars" alt="GitHub Stars"></a>
  <a href="https://github.com/Dai-Ski/LYRA/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License MIT"></a>
  <a href="https://daiski.dev"><img src="https://img.shields.io/badge/Author-daiski.dev-ff6b4a" alt="Author Daiski"></a>
</p>

---

## Features ✨

- 🎤 **Real-Time Synchronized Lyrics**: Displays live, word-by-word scrolling lyrics in your macOS menu bar, perfectly matching playback to the exact second.
- 🔤 **Persistent Romanized Lyrics Mode**: Easily switch to Romanized lyrics for Japanese (Romaji), Korean (Hangul), Chinese (Pinyin), or Hindi tracks. Your preference **stays active across all songs**.
- 🍏 **Spotify & Apple Music Support**: Automatically detects active track changes across Spotify Desktop, Spotify Web, and Apple Music natively.
- ⚡ **Precision Auto-Sync Engine**: Handles subsecond timestamps, studio vs live version matching, and latency compensation for drift-free scrolling.
- 🎨 **Native Apple Aesthetic**: Sleek menu bar emblem designed specifically for macOS Light and Dark modes.
- 🌟 **In-Page Interactive Star Widget**: Support the project right from the download page with one-click animated star feedback.

---

## Installation 🚀

Installing Lyra on macOS is simple:

1. **[Download Lyra.dmg](https://dai-ski.github.io/LYRA/)** *(or use the [Direct DMG Link](https://github.com/Dai-Ski/LYRA/releases/download/v1.0.0/Lyra.dmg))*.
2. Open **`Lyra.dmg`** and drag **Lyra** into your **Applications** folder.
3. Launch **Lyra** from Applications and click **GRANT PERMISSIONS & START**.

> [!IMPORTANT]
> **If macOS displays *"Apple could not verify Lyra is free of malware..."***:  
> Because Lyra is an open-source app distributed outside the Mac App Store, macOS Gatekeeper may show a security prompt on first launch.
> 
> **Quick Fix (choose any option)**:
> - **Option 1 (System Settings)**: Go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**.
> - **Option 2 (Right-Click)**: **Right-click** **Lyra.app** in `/Applications` → select **Open** → click **Open**.
> - **Option 3 (Terminal Command)**: Run `xattr -cr /Applications/Lyra.app` in Terminal.

---

## Romanized Lyrics Mode 🔤

1. Click the **Lyra** icon in your macOS menu bar.
2. Toggle **Romanized Lyrics**.
3. Your setting remains saved! English songs will display original text, while non-Latin tracks (K-Pop, J-Pop, C-Pop, etc.) automatically render Romanized lyrics.

---

## How to Uninstall 🗑️

1. Click the **Lyra** menu bar icon and select **Quit Lyra**.
2. Move **Lyra.app** from your **Applications** folder to the Trash.
3. *(Optional)* Remove from Login Items:
   - Go to **System Settings > General > Login Items & Extensions**.
   - Under **Open at Login**, select **Lyra** and click `-`.


---

## License

This project is licensed under the [MIT License](LICENSE).
