# Lyra 

Lyra is a macOS-only (for now) menu bar application that displays real-time, synchronized scrolling lyrics for the track currently playing in the Spotify or Apple Music desktop applications.
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
Start playing a song on Spotify or Apple Music and launch Lyra:
```bash
lyra
```
The background daemon will boot, and the active lyric line will appear in your top menu bar.

### Package as a macOS App Bundle
To build and package Lyra into a standalone macOS `.app` bundle (which supports automatic launch at login and graphical onboarding dialogs):
```bash
./Scripts/package.sh
```
This will compile the project and generate `Lyra.app` in your repository root, which you can move into `/Applications/`.

---

## Uninstall

To remove Lyra from your system:

1. Close the application by selecting **Quit Lyra** from the menu dropdown (or run `killall Lyra` in the Terminal).
2. Delete the binary from your local path:
   ```bash
   sudo rm /usr/local/bin/lyra
   ```

---

## Future

I plan to expand Lyra's capabilities to more music sources, platforms, and integrations:

1. [x] Apple Music
2. [ ] YouTube Music
3. [ ] Browser Extension
4. [ ] Windows Taskbar

