import AppKit

/// A MainActor-isolated component that manages the macOS Menu Bar status item.
@MainActor
public final class MenuBarEngine: NSObject {
    private var statusItem: NSStatusItem!
    private var areLyricsEnabled: Bool = true
    
    private var originalModeItem: NSMenuItem!
    private var romanizedModeItem: NSMenuItem!
    
    public var modeChangeHandler: ((LyricMode) -> Void)?
    
    // Base64 encoded 32x32 transparent lyre icon (retina status bar size, 16x16 pt)
    private static let lyreIconBase64 = """
    iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAGxlWElmTU0A
    KgAAAAgABAEaAAUAAAABAAAAPgEbAAUAAAABAAAARgEoAAMAAAABAAIAAIdpAAQAAAABAAAATgAA
    AAAAAACQAAAAAQAAAJAAAAABAAKgAgAEAAAAAQAAACCgAwAEAAAAAQAAACAAAAAAxqyL9QAAAAlw
    SFlzAAAWJQAAFiUBSVIk8AAAAsRJREFUWAm1lstLV0EUx83Kkiw3pRgVSLSQkhYRhglhRlEt0qCg
    2gRBkD3B6PUvCOIiKFCjXYsei1qYPSDRzEAoCgysEItei4KemI/y840GLj9n5s7vev3Ch3vvmTPn
    zp05M+fm5Ni1C/MTGIdjdpd0rLmOMB+w58FtaHf4pGKe5YjSjf0h9MOQwycVs2sGTPAibuJ8jG+i
    qy/4LyLWw75EkQM7zfT41dA2D3aC/LQkqcs3A7N5WwfUwRE4D74B05y9fAMYJlwhPIUNUAHXoABS
    k28Av3nLX5gBg7AR/sAdWAzTqgVEfwAvYQUYaTCN8AJWGuN0XPMJegW6wPa1h7BrVqphSnIl1RhR
    l4IOqhug56j6eBiAi/AZnkMi+XJAAeeApt0mHdHaIafhlM0hxOYbgJJQW9GnZzRuga3QDL54NE9W
    XAcVJNcMmGgqXNuhGJQ3OrymrLlEuAtfoTIwmtkh9/EvCezjdFOws6Djd6HTy96gU1NJusreHG7d
    i2sHJJnSHfRTflRBYu2mp5ahIGGEdfTrAeVHItXSqxOSDkAvXQ3KCVVUq3y7QP8DvnZrwAyjluEg
    7IfNkJXO4f0e1mfVa7KzEno5XIdoXfnn6fonVGMZ5IEChEgluxq0ZL1wE0ZAFXUIWkEfdQBUVWOl
    47UL4nJgLT76e9aLoqhvKRjN5+YxyD9IR/FSArkGoGP6DPwEvfgjXIKT0ATvQGW7HDSLy+ATaCli
    pZe2wGvQEZupCgz3wHzxBe6XZDgt4lkx3kAbaFmGIahwrcHxO+gFmsoTsAeOwy3QGqpNZXgbuKQc
    U3s7aEc0Qj7ESrXgKoyC+crodQB7A+jPKVTWLe3aBUoYVblv0AeaRgV4Cz3/+cE1GwVlvhJrE2i6
    xkFf/QUOgysZaUpPSiazd6NTrvtHoAGmqswluEz0QYjaa3hWVXsFY5CqJgAePol+FZY1PQAAAABJ
    RU5ErkJggg==
    """
    
    private lazy var lyreIcon: NSImage? = {
        let cleanedBase64 = Self.lyreIconBase64.components(separatedBy: .whitespacesAndNewlines).joined()
        guard let data = Data(base64Encoded: cleanedBase64) else {
            return nil
        }
        return loadAndProcessIcon(from: data)
    }()
    
    public override init() {
        super.init()
        
        // 1. Create a status item. Start with squareLength for standby icon mode
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        // 2. Configure lineBreakMode to .byClipping to hide ellipsis (...) when text overflows
        if let button = statusItem.button {
            button.title = ""
            button.image = lyreIcon
            button.imagePosition = .imageOnly
            button.lineBreakMode = .byClipping
            button.alignment = .left
        }
        
        // 3. Configure the dropdown menu options
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        // Toggle item to turn lyrics on and off
        let toggleItem = NSMenuItem(
            title: "Show Lyrics",
            action: #selector(toggleLyrics(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.state = areLyricsEnabled ? .on : .off
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Dynamic lyric mode selection items
        originalModeItem = NSMenuItem(
            title: "Original Lyrics",
            action: #selector(setOriginalMode(_:)),
            keyEquivalent: ""
        )
        originalModeItem.target = self
        menu.addItem(originalModeItem)
        
        romanizedModeItem = NSMenuItem(
            title: "Romanized Lyrics",
            action: #selector(setRomanizedMode(_:)),
            keyEquivalent: ""
        )
        romanizedModeItem.target = self
        menu.addItem(romanizedModeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Terminate item to gracefully exit the daemon. No cmd+q key equivalent.
        let quitItem = NSMenuItem(
            title: "Quit Lyra",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: ""
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc private func toggleLyrics(_ sender: NSMenuItem) {
        areLyricsEnabled.toggle()
        sender.state = areLyricsEnabled ? .on : .off
    }
    
    @objc private func setOriginalMode(_ sender: NSMenuItem) {
        modeChangeHandler?(.original)
    }
    
    @objc private func setRomanizedMode(_ sender: NSMenuItem) {
        modeChangeHandler?(.romanized)
    }
    
    private var updateURL: URL?
    
    /// Displays an "Update Lyra" menu option at the top of the menu when a new version is detected.
    @MainActor
    public func showUpdateAvailable(version: String, url: URL) {
        guard let menu = statusItem.menu else { return }
        
        self.updateURL = url
        
        // Prevent duplicate menu item insertions
        if menu.items.contains(where: { $0.action == #selector(openUpdateURL(_:)) }) {
            return
        }
        
        let updateItem = NSMenuItem(
            title: "Update Lyra (\(version))",
            action: #selector(openUpdateURL(_:)),
            keyEquivalent: ""
        )
        updateItem.target = self
        
        menu.insertItem(updateItem, at: 0)
        menu.insertItem(NSMenuItem.separator(), at: 1)
    }
    
    /// Sets the visibility of the status item in the macOS menu bar.
    @MainActor
    public func setVisible(_ visible: Bool) {
        statusItem.isVisible = visible
    }
    
    @objc private func openUpdateURL(_ sender: NSMenuItem) {
        if let url = updateURL {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Updates the menu bar text with the current track playback or synchronized lyric line.
    public func update(
        state: AppPlaybackState,
        lyrics: [LyricLine],
        status: LyricsStatus,
        mode: LyricMode,
        availableModes: [LyricMode]
    ) {
        // Update checkmarks and enabled status dynamically
        originalModeItem.state = (mode == .original) ? .on : .off
        romanizedModeItem.state = (mode == .romanized) ? .on : .off
        
        romanizedModeItem.isEnabled = availableModes.contains(.romanized)
        
        let title: String
        var showOnlyIcon = false
        
        if !areLyricsEnabled {
            title = ""
            showOnlyIcon = true
        } else if !state.isMusicRunning {
            title = ""
            showOnlyIcon = true
        } else if !state.isPlaying && state.title.isEmpty {
            title = ""
            showOnlyIcon = true
        } else if !state.isPlaying {
            // If paused, collapse to icon-only standby mode
            title = ""
            showOnlyIcon = true
        } else {
            // Playing state -> Expand and display text/lyrics
            let currentPos = getCurrentPosition(state: state) + 0.2
            
            if state.title == "Advertisement??" {
                title = "Advertisement??"
            } else {
                switch status {
                case .none, .loading:
                    title = state.title
                case .notFound:
                    title = "Lyrics Not Found"
                case .error(let msg):
                    title = "[Error: \(msg)]"
                case .loaded:
                    let activeIdx = activeLyricIndex(for: currentPos, in: lyrics)
                    
                    if let activeIdx = activeIdx, activeIdx < lyrics.count {
                        let lyricText = lyrics[activeIdx].text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if lyricText.isEmpty {
                            // Instrumental gap inside lyrics -> just music -> cycle music emoji every 2 seconds
                            let elapsedBreak = currentPos - lyrics[activeIdx].timestamp
                            let count = (Int(elapsedBreak / 2.0) % 4) + 1
                            title = String(repeating: "🎵", count: count)
                        } else {
                            // Measure font and split into chunks dynamically to utilize the 130pt space fully
                            let font = statusItem.button?.font ?? NSFont.systemFont(ofSize: 13.0)
                            let chunks = splitIntoDynamicChunks(lyricText, maxWidth: 120.0, font: font)
                            
                            if chunks.isEmpty {
                                title = ""
                            } else {
                                // Calculate start and end timestamps for the current lyric line
                                let tStart = lyrics[activeIdx].timestamp
                                let tEnd: TimeInterval
                                if activeIdx + 1 < lyrics.count {
                                    tEnd = lyrics[activeIdx + 1].timestamp
                                } else {
                                    tEnd = state.duration > tStart ? state.duration : tStart + 8.0
                                }
                                
                                let lineDuration = max(1.0, tEnd - tStart)
                                let elapsed = max(0.0, currentPos - tStart)
                                
                                // Display the appropriate chunk sequentially based on elapsed time within this line
                                let chunkIndex = Int(elapsed / (lineDuration / Double(chunks.count)))
                                let safeIndex = max(0, min(chunks.count - 1, chunkIndex))
                                title = chunks[safeIndex]
                            }
                        }
                    } else {
                        // No active lyric line (intro break) -> cycle music emoji every 2 seconds
                        let count = (Int(currentPos / 2.0) % 4) + 1
                        title = String(repeating: "🎵", count: count)
                    }
                }
            }
        }
        
        // Apply layout geometries and icons
        if let button = statusItem.button {
            if showOnlyIcon {
                statusItem.length = NSStatusItem.squareLength
                button.image = lyreIcon
                button.imagePosition = .imageOnly
                button.title = ""
            } else {
                statusItem.length = 130.0
                button.image = nil
                button.imagePosition = .noImage
                button.title = title
            }
        }
    }
    
    /// Loads the transparent PNG icon and configures it as a template image.
    private func loadAndProcessIcon(from data: Data) -> NSImage? {
        guard let image = NSImage(data: data) else {
            return nil
        }
        image.isTemplate = true
        return image
    }
    
    /// Splits a string into word-boundary-aware chunks that fit visually within maxWidth pixels.
    private func splitIntoDynamicChunks(_ text: String, maxWidth: CGFloat, font: NSFont) -> [String] {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        var chunks: [String] = []
        var currentChunk = ""
        
        for word in words {
            if word.isEmpty { continue }
            
            let candidate = currentChunk.isEmpty ? word : currentChunk + " " + word
            let width = getStringWidth(candidate, font: font)
            
            if width <= maxWidth {
                currentChunk = candidate
            } else {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
                
                // If a single word itself exceeds maxWidth, we split it character-by-character
                let wordWidth = getStringWidth(word, font: font)
                if wordWidth > maxWidth {
                    var remaining = word
                    while !remaining.isEmpty {
                        var sub = ""
                        for char in remaining {
                            let test = sub + String(char)
                            if getStringWidth(test, font: font) <= maxWidth {
                                sub += String(char)
                            } else {
                                break
                            }
                        }
                        if sub.isEmpty {
                            sub = String(remaining.prefix(1))
                        }
                        chunks.append(sub)
                        remaining = String(remaining.dropFirst(sub.count))
                    }
                    currentChunk = ""
                } else {
                    currentChunk = word
                }
            }
        }
        
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        return chunks
    }
    
    /// Computes the visual render width of a string in a specific font.
    private func getStringWidth(_ text: String, font: NSFont) -> CGFloat {
        let attributes = [NSAttributedString.Key.font: font]
        return (text as NSString).size(withAttributes: attributes).width
    }
    
    private func getCurrentPosition(state: AppPlaybackState) -> TimeInterval {
        guard state.isPlaying else { return state.position }
        let elapsed = Date().timeIntervalSince(state.lastUpdated)
        return min(state.duration, state.position + elapsed)
    }
    
    private func activeLyricIndex(for position: Double, in lyrics: [LyricLine]) -> Int? {
        guard !lyrics.isEmpty else { return nil }
        var activeIndex: Int? = nil
        for (index, line) in lyrics.enumerated() {
            if line.timestamp <= position {
                activeIndex = index
            } else {
                break
            }
        }
        return activeIndex
    }
}