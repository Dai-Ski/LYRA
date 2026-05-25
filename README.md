# Lyra 🎵

Lyra is a macOS-only (for now) menu bar application that displays real-time, synchronized scrolling lyrics for the track currently playing in the Spotify desktop application.
---

## Menu Bar Preview

![Lyra Preview](Assets/preview.png)

---



## Installation 

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

## Future

I plan to expand Lyra's capabilities to more music sources, platforms, and integrations:

1. Apple Music
2. YouTube Music
3. Browser Extension
4. Windows Taskbar

