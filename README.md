# Lyra 🎵

Lyra is a high-performance, lightweight macOS menu bar application that displays real-time, synchronized scrolling lyrics in your system status bar for the track currently playing in the Spotify desktop application.

Built natively in **Swift 6** using AppKit and zero third-party dependencies, Lyra runs as an accessory background daemon with a near-zero CPU and memory footprint.

---

## Menu Bar Preview

![Lyra Preview](Assets/preview.png)

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


## Future Roadmap

We plan to expand Lyra's capabilities to more music sources, platforms, and integrations:

### 1. Apple Music
### 2. YouTube Music
### 3. Browser Extension
### 4. Windows Taskbar

