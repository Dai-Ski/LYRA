import AppKit

/// A MainActor-isolated component that manages the macOS Menu Bar status item.
@MainActor
public final class MenuBarEngine: NSObject {
    private var statusItem: NSStatusItem!
    private var areLyricsEnabled: Bool = true
    
    private var originalModeItem: NSMenuItem!
    private var romanizedModeItem: NSMenuItem!
    
    public var modeChangeHandler: ((LyricMode) -> Void)?
    
    // Base64 encoded 36x36 retina stencil lyre icon (18x18 pt menu bar size)
    private static let lyreIconBase64 = """
    iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAACBUlEQVR4nO2WT0hUURTGf5NKGRZj
    IUYhLooYnI1Ci1azSpLaKgVtBaUgAnFfuJMg+rOXIQiC2rUS3bgJQRfRMhfioinNmf4PU44jF74r
    h8dAE9z3ZvM+eHzvnXvfvR/nnnvOgRQpUsSLTAxrjgGDQLe+/wINYBt4RcK4oc2bPXdbWaAzsKDz
    wB89HWLnqSLwhDbgC1AH9iLeud/qAkcCipkCTgM1fX8AHund2RPHNx3Rb3nlpOzufTVpMY+1cVW8
    ZsY2dYSJoV8ifojnZC+In8qeT0rQhgliHz8Ot8RXNfYgCTHz2szFzjIwAlzQ2LS4S3Pexi0mb8Q4
    Pi77NbFNhFUFe6zXfkVlwR3ZOHBO9l6xDeQtU0piEfQGOKXjuAy8BnIaO2G8YgU59MVROiaA6yqW
    C8aeFR8TV8zYZ/EZYCe0oKI4p02vAEtG0L64bP6ptrrf/x7ZomJhwnjAx8xRsb/6FZOtXaFFdS6Y
    oAIwCjyM9DU9YnfTrDd2jddcvDl8DynoueJmNmK/GImdj+bIfCoYEJcIhKw84GqWx4y84FuMn8Bt
    4J6ZMyz+ajwYBENacF1BvKpvVzifAS8VH17cJf3nc1ND3UBQlCJNl2tXm+WnhhF/07S174kBd4DJ
    f8x5YcqJf2o6trO0CWUJqUf4XdJNvscvkyQzEuRy0afDGSlSpKA9OABSaI94Z9c52QAAAABJRU5E
    RkJggg==
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
        
        romanizedModeItem.isEnabled = true
        
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
            let currentPos = getCurrentPosition(state: state) + 0.1
            
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
                            } else if chunks.count == 1 {
                                title = chunks[0]
                            } else {
                                // Calculate start and end timestamps for the current lyric line
                                let tStart = lyrics[activeIdx].timestamp
                                let tEnd: TimeInterval
                                if activeIdx + 1 < lyrics.count {
                                    tEnd = lyrics[activeIdx + 1].timestamp
                                } else {
                                    tEnd = state.duration > tStart ? state.duration : tStart + 8.0
                                }
                                
                                let gap = max(0.5, tEnd - tStart)
                                let elapsed = max(0.0, currentPos - tStart)
                                
                                // Allocate active singing time window for advancing chunks
                                let minTimePerChunk = 2.2
                                let activeWindow = min(gap, max(minTimePerChunk * Double(chunks.count), gap * 0.65))
                                
                                // Distribute activeWindow proportionally by character length
                                let totalChars = chunks.reduce(0) { $0 + max(1, $1.count) }
                                var currentOffset = 0.0
                                var selectedChunkIndex = chunks.count - 1
                                
                                for (i, chunk) in chunks.enumerated() {
                                    let chunkWeight = Double(max(1, chunk.count)) / Double(totalChars)
                                    let chunkDuration = activeWindow * chunkWeight
                                    if elapsed < currentOffset + chunkDuration {
                                        selectedChunkIndex = i
                                        break
                                    }
                                    currentOffset += chunkDuration
                                }
                                
                                title = chunks[selectedChunkIndex]
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
        image.size = NSSize(width: 18, height: 18)
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