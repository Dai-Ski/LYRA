# Lyra 🎵

Lyra is a high-performance, lightweight macOS menu bar application that displays real-time, synchronized scrolling lyrics in your system status bar for the track currently playing in the Spotify desktop application.

Built natively in **Swift 6** using AppKit and zero third-party dependencies, Lyra runs as an accessory background daemon with a near-zero CPU and memory footprint.

---

## Menu Bar Preview

![Lyra Preview](Assets/preview.png)

---

## Features

- **Menu Bar Integration**: Displays the active synchronized lyric line directly at the top of your screen.
- **Dynamic Updates**: Smoothly transitions lyric lines in real-time as the song plays.
- **Accessory Daemon**: Runs with activation policy `.accessory` (no Dock icon, no window overhead).
- **Standby & Paused States**: Collapses to show only the premium harp status bar icon when Spotify is paused or inactive.
- **Lyrics Toggle**: Click the menu bar icon or text to open the dropdown and toggle **Show Lyrics** on or off. When off, collapses to the harp icon.
- **Clean Loading State**: Shows only the song name in the Menu Bar during background lyrics retrieval (no `[loading...]` prefix).
- **"Lyrics Not Found" Indicator**: Displays a clear `"Lyrics Not Found"` message in the Menu Bar if lyrics are unavailable for the current track.
- **Advertisement Detection**: Identifies Spotify advertisements and unrecognized audio streams. Displays exactly `"Advertisement??"` in the Menu Bar and avoids redundant lyrics fetching.
- **Robust Automation**: AppleScript query uses `try` blocks to gracefully fetch track metadata from Spotify without crashing on missing tags (common on ads, local files, and podcasts).
- **Automatic Update Checker**: Queries the GitHub releases API asynchronously on launch. If a newer version is available, it dynamically displays an **"Update Lyra (vX.Y.Z)"** option at the top of the menu to let you open the release page in your browser.
- **Graceful Termination**: Can be closed by clicking the menu bar item and selecting **Quit Lyra**. (The keyboard shortcut `Cmd+Q` is disabled to prevent accidental closure).

---

## Repository Structure

The codebase is organized cleanly and follows Apple's standard Swift Package Manager project structure:

```text
Lyra/
├── Assets/
│   └── preview.png          # High-resolution screenshot of the menu bar interface
├── Sources/
│   └── Lyra/
│       ├── main.swift       # Application entry point, CLI arguments, and AppDelegate orchestration
│       ├── Models.swift     # Core structures (LyricLine, SpotifyTrack, etc.) and state Actor
│       ├── LyricsClient.swift # LRCLIB network client fetching synchronized lyrics
│       ├── MenuBarEngine.swift# macOS status bar statusItem renderer and menu toggle management
│       ├── SpotifyBridge.swift# AppleScript automation layer for fetching Spotify states
│       └── UpdateChecker.swift# Asynchronous updater checking GitHub releases
├── Tests/
│   └── LyraTests/
│       └── LyraTests.swift  # Boilerplate Swift testing suites
├── Package.swift            # Swift Package Manager package configuration file
└── README.md                # Project documentation and manual
```

---

## Installation & Build

### Prerequisites
- **macOS 13.0** (Ventura) or newer.
- **Xcode Command Line Tools** (Swift 6.0 toolchain or newer).

### Build from Source
Clone the repository and compile using Swift Package Manager in release configuration:

```bash
# Clone the repository
git clone https://github.com/Dai-Ski/LYRA.git
cd LYRA

# Build the binary in Release mode
swift build -c release

# Install the compiled binary to your local execution path
sudo cp .build/release/Lyra /usr/local/bin/lyra
```

Verify the installation is successful:
```bash
lyra --version
```

---

## Usage

Start playing a song on Spotify and launch Lyra:
```bash
lyra
```

The background daemon will boot, and the active lyric line will appear in your top menu bar.

### CLI Options

| Flag | Description |
|---|---|
| `-d, --debug` | Prints network requests and AppleScript metadata events in the terminal. |
| `--interval <seconds>` | Overrides the default Spotify metadata polling rate (default: `2.0`s). |
| `-v, --version` | Prints the version information. |
| `-h, --help` | Displays the help manual. |

To close Lyra, click the status item in the menu bar and select **Quit Lyra**.

---

## Releases & Swift Package Integration

Lyra is published as a Swift Package. You can download pre-compiled releases, view tags, or import the package using the [GitHub Releases Page](https://github.com/Dai-Ski/LYRA/releases).

### Version checking
Lyra features an automatic update checker. On application startup, it queries GitHub Releases asynchronously. If a newer version tag (e.g. `v1.0.1`) is available, it dynamically prepends **"Update Lyra (vX.Y.Z)"** to the status bar dropdown. Clicking it opens the web browser directly to the release page.

---

## Required macOS Permissions

Since Lyra communicates with the Spotify application via `NSAppleScript`, macOS enforces automation security boundaries.

1. On the first launch, macOS will request permission to let your terminal emulator control Spotify:
   > **"Terminal" would like to control "Spotify"**
2. Click **OK**.
3. If you deny permissions, Lyra will show an error in the menu bar: `⚠️ [Error: Automation permission denied...]`
4. To fix this:
   - Open **System Settings** > **Privacy & Security** > **Automation**.
   - Find your Terminal application (e.g., *Terminal*, *iTerm2*, or *VS Code*).
   - Ensure the switch next to **Spotify** is enabled.

---

## Future Roadmap

We plan to expand Lyra's capabilities to more music sources, platforms, and integrations:

### 1. Apple Music
- Extend AppleScript automation triggers to read metadata from the native macOS **Music** app when active.
- Seamlessly transition between Spotify and Apple Music depending on which app is currently playing.

### 2. YouTube Music
- Read YouTube Music track playback status and metadata from browsers or desktop wrapper apps.

### 3. Browser Extension
- Develop a lightweight Chrome/Firefox/Safari browser extension to extract tab music states (YouTube Music, Soundcloud, etc.) and forward them to Lyra.

### 4. Windows Taskbar
- Port the lightweight core logic to Windows using C#/.NET or Rust.
- Display synchronized lyrics directly in the Windows Taskbar or system tray.
