import AppKit

/// A MainActor-isolated component that manages the macOS Menu Bar status item.
@MainActor
public final class MenuBarEngine: NSObject {
    private var statusItem: NSStatusItem!
    private var areLyricsEnabled: Bool = true
    
    private var originalModeItem: NSMenuItem!
    private var romanizedModeItem: NSMenuItem!
    
    public var modeChangeHandler: ((LyricMode) -> Void)?
    
    private static func createVectorSpeechBubbleLyricIcon() -> NSImage {
        let targetSize = NSSize(width: 24, height: 24)
        let image = NSImage(size: targetSize, flipped: false) { rect in
            NSColor.labelColor.setStroke()
            NSColor.labelColor.setFill()
            
            // 1. Boxy Speech Bubble Outer Path (squarish rectangle with corner radius 2.5)
            let bubbleRect = NSRect(x: 3.0, y: 5.0, width: 18.0, height: 14.5)
            let cornerRadius: CGFloat = 2.5
            
            let path = NSBezierPath()
            // Top-left corner
            path.move(to: NSPoint(x: bubbleRect.minX + cornerRadius, y: bubbleRect.maxY))
            
            // Top edge to top-right
            path.line(to: NSPoint(x: bubbleRect.maxX - cornerRadius, y: bubbleRect.maxY))
            path.appendArc(
                from: NSPoint(x: bubbleRect.maxX, y: bubbleRect.maxY),
                to: NSPoint(x: bubbleRect.maxX, y: bubbleRect.maxY - cornerRadius),
                radius: cornerRadius
            )
            
            // Right edge to bottom-right
            path.line(to: NSPoint(x: bubbleRect.maxX, y: bubbleRect.minY + cornerRadius))
            path.appendArc(
                from: NSPoint(x: bubbleRect.maxX, y: bubbleRect.minY),
                to: NSPoint(x: bubbleRect.maxX - cornerRadius, y: bubbleRect.minY),
                radius: cornerRadius
            )
            
            // Bottom edge to tail
            path.line(to: NSPoint(x: bubbleRect.minX + 8.5, y: bubbleRect.minY))
            
            // Tail pointing down-left
            path.line(to: NSPoint(x: bubbleRect.minX + 3.5, y: bubbleRect.minY - 3.5))
            path.line(to: NSPoint(x: bubbleRect.minX + 5.5, y: bubbleRect.minY))
            
            // Bottom-left corner
            path.line(to: NSPoint(x: bubbleRect.minX + cornerRadius, y: bubbleRect.minY))
            path.appendArc(
                from: NSPoint(x: bubbleRect.minX, y: bubbleRect.minY),
                to: NSPoint(x: bubbleRect.minX, y: bubbleRect.minY + cornerRadius),
                radius: cornerRadius
            )
            
            // Left edge back to top-left
            path.line(to: NSPoint(x: bubbleRect.minX, y: bubbleRect.maxY - cornerRadius))
            path.appendArc(
                from: NSPoint(x: bubbleRect.minX, y: bubbleRect.maxY),
                to: NSPoint(x: bubbleRect.minX + cornerRadius, y: bubbleRect.maxY),
                radius: cornerRadius
            )
            
            path.lineWidth = 1.8
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
            
            // 2. Horizontal Lyric Text Bars inside boxy bubble
            let line1 = NSBezierPath(roundedRect: NSRect(x: 6.5, y: 13.5, width: 11.0, height: 2.0), xRadius: 0.8, yRadius: 0.8)
            line1.fill()
            
            let line2 = NSBezierPath(roundedRect: NSRect(x: 6.5, y: 9.5, width: 8.0, height: 2.0), xRadius: 0.8, yRadius: 0.8)
            line2.fill()
            
            return true
        }
        image.isTemplate = true
        return image
    }
    
    private static func loadRomanizedSVGIcon() -> NSImage? {
        let rawImage: NSImage?
        if let bundleUrl = Bundle.module.url(forResource: "romanized_custom", withExtension: "svg"), let img = NSImage(contentsOf: bundleUrl) {
            rawImage = img
        } else if let img = NSImage(contentsOfFile: "Sources/Lyra/Resources/romanized_custom.svg") {
            rawImage = img
        } else {
            rawImage = nil
        }
        
        guard let source = rawImage else { return nil }
        
        let canvasSize = NSSize(width: 24, height: 24)
        let iconSize = NSSize(width: 17, height: 17)
        let origin = NSPoint(x: (canvasSize.width - iconSize.width) / 2.0, y: (canvasSize.height - iconSize.height) / 2.0)
        
        let templateImage = NSImage(size: canvasSize, flipped: false) { rect in
            let iconRect = NSRect(origin: origin, size: iconSize)
            source.draw(in: iconRect)
            return true
        }
        templateImage.isTemplate = true
        return templateImage
    }

    private lazy var translateIcon: NSImage? = {
        Self.loadRomanizedSVGIcon()
    }()
    
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
    
    private var topHeaderView: TopHeaderMenuView!
    private var dropdownMenu: NSMenu!

    private func setupMenu() {
        let menu = NSMenu()
        
        // 1. Single Top Header Control Line: Traffic Light Controller + Translate SVG Mode Button + Media Controls
        topHeaderView = TopHeaderMenuView(translateIcon: translateIcon)
        topHeaderView.quitHandler = {
            NSApplication.shared.terminate(nil)
        }
        topHeaderView.hideLyricsHandler = { [weak self] in
            guard let self = self else { return }
            self.areLyricsEnabled = false
            self.dropdownMenu?.cancelTracking()
        }
        topHeaderView.showLyricsHandler = { [weak self] in
            guard let self = self else { return }
            self.areLyricsEnabled = true
            self.dropdownMenu?.cancelTracking()
        }
        topHeaderView.openMusicAppHandler = { [weak self] in
            MediaControlsManager.openActiveMusicApp()
            self?.dropdownMenu?.cancelTracking()
        }
        topHeaderView.modeChangeHandler = { [weak self] mode in
            self?.modeChangeHandler?(mode)
        }
        topHeaderView.seekHandler = { position in
            MediaControlsManager.seek(to: position)
        }
        topHeaderView.previousTrackHandler = {
            MediaControlsManager.previousTrack()
        }
        topHeaderView.playPauseHandler = {
            MediaControlsManager.togglePlayPause()
        }
        topHeaderView.nextTrackHandler = {
            MediaControlsManager.nextTrack()
        }
        let topItem = NSMenuItem()
        topItem.view = topHeaderView
        menu.addItem(topItem)
        
        self.dropdownMenu = menu
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    @objc private func statusItemButtonClicked(_ sender: NSStatusBarButton) {
        guard let menu = dropdownMenu else { return }
        // Match right corner + shift a bit more (10pt) right
        let menuWidth: CGFloat = 210.0
        let xOffset = (sender.bounds.width - menuWidth) + 10.0
        let point = NSPoint(x: xOffset, y: 0.0)
        menu.popUp(positioning: nil, at: point, in: sender)
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
        topHeaderView?.setPlaybackState(isPlaying: state.isPlaying)
        topHeaderView?.setLyricsState(areLyricsEnabled: areLyricsEnabled)
        topHeaderView?.setMode(mode)
        topHeaderView?.setProgress(position: state.position, duration: state.duration)
        topHeaderView?.setTrackTitle(state.title, artist: state.artist)
        
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
                            // Measure font and split into chunks dynamically to utilize the expanded space fully
                            let font = statusItem.button?.font ?? NSFont.systemFont(ofSize: 13.0)
                            let chunks = splitIntoDynamicChunks(lyricText, maxWidth: 125.0, font: font)
                            
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
                statusItem.length = 140.0
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
        image.size = NSSize(width: 22, height: 22)
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

/// Container view that manages the native macOS Red (Close), Yellow (Minimize), and Green (Expand) Traffic Light buttons with group hover state.
@MainActor
final class TrafficLightsContainerView: NSView {
    override var isFlipped: Bool { return true }
    private var isGroupHovered: Bool = false
    private var trackingArea: NSTrackingArea?
    
    var areLyricsEnabled: Bool = true {
        didSet {
            redrawButtons()
        }
    }
    
    let redButton: NSButton
    let yellowButton: NSButton
    let greenButton: NSButton
    
    var quitHandler: (() -> Void)?
    var hideLyricsHandler: (() -> Void)?
    var showLyricsHandler: (() -> Void)?
    var openMusicAppHandler: (() -> Void)?
    
    override init(frame frameRect: NSRect) {
        self.redButton = NSButton()
        self.yellowButton = NSButton()
        self.greenButton = NSButton()
        
        super.init(frame: frameRect)
        
        setupButtons()
        updateTrackingAreas()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupButtons() {
        for btn in [redButton, yellowButton, greenButton] {
            btn.isBordered = false
            btn.setButtonType(.momentaryChange)
            addSubview(btn)
        }
        
        redButton.frame = NSRect(x: 0, y: 2, width: 10.2, height: 10.2)
        redButton.target = self
        redButton.action = #selector(redClicked(_:))
        
        yellowButton.frame = NSRect(x: 14.2, y: 2, width: 10.2, height: 10.2)
        yellowButton.target = self
        yellowButton.action = #selector(yellowClicked(_:))
        
        greenButton.frame = NSRect(x: 28.4, y: 2, width: 10.2, height: 10.2)
        greenButton.target = self
        greenButton.action = #selector(greenClicked(_:))
        
        redrawButtons()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let old = trackingArea {
            removeTrackingArea(old)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.trackingArea = area
    }
    
    override func mouseEntered(with event: NSEvent) {
        isGroupHovered = true
        redrawButtons()
    }
    
    override func mouseExited(with event: NSEvent) {
        isGroupHovered = false
        redrawButtons()
    }
    
    private func redrawButtons() {
        redButton.image = createRedImage(showSymbol: isGroupHovered)
        yellowButton.image = createYellowImage(showSymbol: isGroupHovered)
        greenButton.image = createGreenImage(showSymbol: isGroupHovered)
    }
    
    private func createRedImage(showSymbol: Bool) -> NSImage {
        return NSImage(size: NSSize(width: 10.2, height: 10.2), flipped: false) { rect in
            // 1. Red Fill (#FF5F56)
            NSColor(red: 1.0, green: 0.37, blue: 0.34, alpha: 1.0).setFill()
            let circle = NSBezierPath(ovalIn: NSRect(x: 0.5, y: 0.5, width: 9.2, height: 9.2))
            circle.fill()
            
            // 2. Red Outline (#E0443E)
            NSColor(red: 0.88, green: 0.27, blue: 0.24, alpha: 1.0).setStroke()
            circle.lineWidth = 0.5
            circle.stroke()
            
            // 3. Hover Symbol: Dark 'x' cross
            if showSymbol {
                NSColor(red: 0.3, green: 0.0, blue: 0.0, alpha: 0.85).setStroke()
                let xPath = NSBezierPath()
                xPath.lineWidth = 0.8
                xPath.move(to: NSPoint(x: 2.8, y: 2.8))
                xPath.line(to: NSPoint(x: 7.4, y: 7.4))
                xPath.move(to: NSPoint(x: 7.4, y: 2.8))
                xPath.line(to: NSPoint(x: 2.8, y: 7.4))
                xPath.stroke()
            }
            return true
        }
    }
    
    private func createYellowImage(showSymbol: Bool) -> NSImage {
        return NSImage(size: NSSize(width: 10.2, height: 10.2), flipped: false) { rect in
            // 1. Yellow Fill (#FFBD2E)
            NSColor(red: 1.0, green: 0.74, blue: 0.18, alpha: 1.0).setFill()
            let circle = NSBezierPath(ovalIn: NSRect(x: 0.5, y: 0.5, width: 9.2, height: 9.2))
            circle.fill()
            
            // 2. Yellow Outline (#D6A21D)
            NSColor(red: 0.84, green: 0.64, blue: 0.11, alpha: 1.0).setStroke()
            circle.lineWidth = 0.5
            circle.stroke()
            
            // 3. Hover Symbol: '-' when lyrics are seen (areLyricsEnabled == true), '+' when lyrics are not shown (areLyricsEnabled == false)
            if showSymbol {
                NSColor(red: 0.3, green: 0.2, blue: 0.0, alpha: 0.85).setStroke()
                let symbolPath = NSBezierPath()
                symbolPath.lineWidth = 0.8
                
                // Horizontal line (common to '-' and '+')
                symbolPath.move(to: NSPoint(x: 2.5, y: 5.1))
                symbolPath.line(to: NSPoint(x: 7.6, y: 5.1))
                
                // Vertical line for '+' when lyrics are not shown
                if !self.areLyricsEnabled {
                    symbolPath.move(to: NSPoint(x: 5.1, y: 2.5))
                    symbolPath.line(to: NSPoint(x: 5.1, y: 7.6))
                }
                
                symbolPath.stroke()
            }
            return true
        }
    }
    
    private func createGreenImage(showSymbol: Bool) -> NSImage {
        return NSImage(size: NSSize(width: 10.2, height: 10.2), flipped: false) { rect in
            // 1. Green Fill (#28C840)
            NSColor(red: 0.16, green: 0.78, blue: 0.25, alpha: 1.0).setFill()
            let circle = NSBezierPath(ovalIn: NSRect(x: 0.5, y: 0.5, width: 9.2, height: 9.2))
            circle.fill()
            
            // 2. Green Outline (#1D9C31)
            NSColor(red: 0.11, green: 0.61, blue: 0.19, alpha: 1.0).setStroke()
            circle.lineWidth = 0.5
            circle.stroke()
            
            // 3. Hover Symbol: Native Apple Expand / Maximize Triangles (↗ ↙)
            if showSymbol {
                NSColor(red: 0.0, green: 0.25, blue: 0.05, alpha: 0.85).setFill()
                
                // Upper Right Triangle (pointing ↗)
                let tri1 = NSBezierPath()
                tri1.move(to: NSPoint(x: 3.8, y: 7.4))
                tri1.line(to: NSPoint(x: 7.4, y: 7.4))
                tri1.line(to: NSPoint(x: 7.4, y: 3.8))
                tri1.close()
                tri1.fill()
                
                // Lower Left Triangle (pointing ↙)
                let tri2 = NSBezierPath()
                tri2.move(to: NSPoint(x: 2.8, y: 6.4))
                tri2.line(to: NSPoint(x: 2.8, y: 2.8))
                tri2.line(to: NSPoint(x: 6.4, y: 2.8))
                tri2.close()
                tri2.fill()
            }
            return true
        }
    }
    
    @objc private func redClicked(_ sender: NSButton) {
        quitHandler?()
    }
    
    @objc private func yellowClicked(_ sender: NSButton) {
        if areLyricsEnabled {
            hideLyricsHandler?()
        } else {
            showLyricsHandler?()
        }
    }
    
    @objc private func greenClicked(_ sender: NSButton) {
        openMusicAppHandler?()
    }
}

/// Helper to dispatch media playback commands to Spotify or Apple Music via AppleScript.
@MainActor
public struct MediaControlsManager {
    public static func previousTrack() {
        Task.detached {
            let script = """
            tell application "System Events"
                if exists (process "Spotify") then
                    tell application "Spotify" to previous track
                else if exists (process "Music") then
                    tell application "Music" to previous track
                end if
            end tell
            """
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
        }
    }

    public static func togglePlayPause() {
        Task.detached {
            let script = """
            tell application "System Events"
                if exists (process "Spotify") then
                    tell application "Spotify" to playpause
                else if exists (process "Music") then
                    tell application "Music" to playpause
                end if
            end tell
            """
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
        }
    }

    public static func nextTrack() {
        Task.detached {
            let script = """
            tell application "System Events"
                if exists (process "Spotify") then
                    tell application "Spotify" to next track
                else if exists (process "Music") then
                    tell application "Music" to next track
                end if
            end tell
            """
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
        }
    }

    public static func seek(to position: Double) {
        Task.detached {
            let script = """
            tell application "System Events"
                if exists (process "Spotify") then
                    tell application "Spotify" to set player position to \(position)
                else if exists (process "Music") then
                    tell application "Music" to set player position to \(position)
                end if
            end tell
            """
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
        }
    }

    public static func openActiveMusicApp() {
        Task.detached {
            let script = """
            tell application "System Events"
                if exists (process "Spotify") then
                    tell application "Spotify"
                        reopen
                        activate
                    end tell
                else if exists (process "Music") then
                    tell application "Music"
                        reopen
                        activate
                    end tell
                else
                    do shell script "open -a 'Music' 2>/dev/null || open -a 'Spotify' 2>/dev/null"
                end if
            end tell
            """
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
            
            let apps = NSWorkspace.shared.runningApplications
            if let spotify = apps.first(where: { $0.bundleIdentifier == "com.spotify.client" }) {
                spotify.activate(options: [.activateIgnoringOtherApps])
            } else if let music = apps.first(where: { $0.bundleIdentifier == "com.apple.Music" }) {
                music.activate(options: [.activateIgnoringOtherApps])
            }
        }
    }
}
/// Custom NSSliderCell overriding drawBar for Electric Blue (#0088FF) track fill,
/// while delegating drawKnob to super.drawKnob to preserve 100% native system thumb rendering.
@MainActor
final class CustomProgressSliderCell: NSSliderCell {
    override func drawBar(inside aRect: NSRect, flipped: Bool) {
        var trackRect = aRect
        trackRect.size.height = 3.0
        trackRect.origin.y = aRect.origin.y + (aRect.size.height - trackRect.size.height) / 2.0
        
        let cornerRadius: CGFloat = 1.5
        
        // 1. Background Track (Unelapsed - soft secondary system gray)
        let bgPath = NSBezierPath(roundedRect: trackRect, xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor.labelColor.withAlphaComponent(0.18).setFill()
        bgPath.fill()
        
        // 2. Active Progress Track (Electric Blue #0088FF)
        let range = maxValue - minValue
        let valueFraction = (range > 0) ? (doubleValue - minValue) / range : 0.0
        
        let fillWidth = max(0, trackRect.width * CGFloat(valueFraction))
        if fillWidth > 0 {
            let fillRect = NSRect(x: trackRect.origin.x, y: trackRect.origin.y, width: fillWidth, height: trackRect.size.height)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: cornerRadius, yRadius: cornerRadius)
            NSColor(red: 0.0 / 255.0, green: 136.0 / 255.0, blue: 255.0 / 255.0, alpha: 1.0).setFill()
            fillPath.fill()
        }
    }
    
    override func drawKnob(_ knobRect: NSRect) {
        super.drawKnob(knobRect)
    }
}

/// Custom NSView for top menu header containing:
/// 1. Row 1 (Top): Traffic Lights (Quit Red, Minimise Yellow, Maximise Green) at top left
/// 2. Row 2 (Middle): Playback Timeline (Elapsed Time, Seek Progress Bar Slider, Total Duration)
/// 3. Row 3 (Bottom): Song Navigations (Previous, Play/Pause, Next) & Original / Romanized Lyric circular buttons
@MainActor
final class TopHeaderMenuView: NSView {
    override var isFlipped: Bool { return true }
    
    private static let coffeeCupIconBase64 = "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pMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTdFpMTnBqN1V2dXA4MTFzNXZXA4ODFxN3V1cWFwcmZ3dWV6eW9kMjZ4cXhpYnFwbnlyNmZ1bTAxMjZ4dTR0bTRoIn0="

    private lazy var coffeeCupIcon: NSImage? = {
        let size = NSSize(width: 12.47, height: 16.62)
        let yellowImg: NSImage? = {
            if let url = Bundle.module.url(forResource: "coffee_yellow", withExtension: "png") {
                return NSImage(contentsOf: url)
            }
            return nil
        }()
        let outlineImg: NSImage? = {
            if let url = Bundle.module.url(forResource: "coffee_outline", withExtension: "png"),
               let img = NSImage(contentsOf: url) {
                img.isTemplate = true
                return img
            }
            return nil
        }()
        
        if let yellow = yellowImg, let outline = outlineImg {
            let tintedOutline = NSImage(size: size, flipped: false) { rect in
                outline.draw(in: rect)
                NSColor.secondaryLabelColor.set()
                rect.fill(using: .sourceIn)
                return true
            }
            return NSImage(size: size, flipped: false) { rect in
                yellow.draw(in: rect)
                tintedOutline.draw(in: rect)
                return true
            }
        }
        
        if let url = Bundle.module.url(forResource: "coffee_cup", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = size
            return image
        }
        return nil
    }()

    let trafficLights: TrafficLightsContainerView
    let appTitleIconButton: NSButton
    let appTitleLabel: NSTextField
    let songTitleLabel: NSTextField
    let separatorLine1: NSBox
    let elapsedLabel: NSTextField
    let progressSlider: NSSlider
    let durationLabel: NSTextField
    let prevButton: NSButton
    let playPauseButton: NSButton
    let nextButton: NSButton
    let translateButton: NSButton
    
    private var currentMode: LyricMode = .original
    private var isUserSeeking: Bool = false
    private var lastSeekTimestamp: Date = Date.distantPast
    
    var quitHandler: (() -> Void)? {
        didSet { trafficLights.quitHandler = quitHandler }
    }
    var hideLyricsHandler: (() -> Void)? {
        didSet { trafficLights.hideLyricsHandler = hideLyricsHandler }
    }
    var showLyricsHandler: (() -> Void)? {
        didSet { trafficLights.showLyricsHandler = showLyricsHandler }
    }
    var openMusicAppHandler: (() -> Void)? {
        didSet { trafficLights.openMusicAppHandler = openMusicAppHandler }
    }
    
    var modeChangeHandler: ((LyricMode) -> Void)?
    var seekHandler: ((Double) -> Void)?
    var previousTrackHandler: (() -> Void)?
    var playPauseHandler: (() -> Void)?
    var nextTrackHandler: (() -> Void)?
    
    init(translateIcon: NSImage?) {
        self.trafficLights = TrafficLightsContainerView(frame: NSRect(x: 8, y: 0.5, width: 48, height: 12))
        self.appTitleIconButton = NSButton()
        self.appTitleLabel = NSTextField(labelWithString: "Lyra")
        self.songTitleLabel = NSTextField(labelWithString: "")
        self.separatorLine1 = NSBox()
        self.elapsedLabel = NSTextField(labelWithString: "0:00")
        self.progressSlider = NSSlider()
        self.durationLabel = NSTextField(labelWithString: "0:00")
        self.prevButton = NSButton()
        self.playPauseButton = NSButton()
        self.nextButton = NSButton()
        self.translateButton = NSButton()
        
        super.init(frame: NSRect(x: 0, y: 0, width: 210, height: 86))
        
        // 1. Row 1 (Top Edge): App Title "Lyra" (centered), Coffee Cup Icon (right corner), & Traffic Lights (left corner)
        let k2dFont = NSFont(name: "K2D", size: 12)
            ?? NSFont(name: "K2D-Bold", size: 12)
            ?? NSFont(name: "K2D-Regular", size: 12)
            ?? NSFont.systemFont(ofSize: 11.5, weight: .bold)
        appTitleLabel.font = k2dFont
        appTitleLabel.textColor = .secondaryLabelColor
        appTitleLabel.alignment = .center
        appTitleLabel.frame = NSRect(x: 6, y: -0.5, width: 210, height: 14)
        addSubview(appTitleLabel)
        
        appTitleIconButton.isBordered = false
        appTitleIconButton.title = ""
        appTitleIconButton.image = coffeeCupIcon
        appTitleIconButton.imageScaling = .scaleProportionallyUpOrDown
        appTitleIconButton.frame = NSRect(x: 186, y: -0.34, width: 12.47, height: 16.62)
        appTitleIconButton.target = self
        appTitleIconButton.action = #selector(openBuyMeACoffee(_:))
        addSubview(appTitleIconButton)
        
        addSubview(trafficLights)
        
        // 2. Partition 1 (Separator Line 1)
        separatorLine1.boxType = .separator
        separatorLine1.frame = NSRect(x: 8, y: 19, width: 194, height: 1)
        addSubview(separatorLine1)
        
        // 3. Row 2 (After Partition & Above Controllers): Song Name Display in K2D font
        let k2dSongTitleFont = NSFont(name: "K2D", size: 11.5)
            ?? NSFont(name: "K2D-SemiBold", size: 11.5)
            ?? NSFont(name: "K2D-Regular", size: 11.5)
            ?? NSFont.systemFont(ofSize: 10.5, weight: .semibold)
        songTitleLabel.font = k2dSongTitleFont
        songTitleLabel.textColor = .labelColor
        songTitleLabel.alignment = .center
        songTitleLabel.lineBreakMode = .byTruncatingTail
        songTitleLabel.frame = NSRect(x: 8, y: 24, width: 194, height: 14)
        addSubview(songTitleLabel)
        
        // 4. Row 3 (Middle): Song Control Buttons (Expanded spacing) & Custom Translate SVG Mode Button
        let navConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let playPauseConfig = NSImage.SymbolConfiguration(pointSize: 17, weight: .bold)
        
        let prevImg = NSImage(systemSymbolName: "backward.fill", accessibilityDescription: "Previous Track")?.withSymbolConfiguration(navConfig)
        prevButton.image = prevImg
        prevButton.isBordered = false
        prevButton.setButtonType(.momentaryChange)
        prevButton.contentTintColor = .labelColor
        prevButton.frame = NSRect(x: 8, y: 42, width: 34, height: 24)
        prevButton.target = self
        prevButton.action = #selector(prevClicked(_:))
        addSubview(prevButton)
        
        let playPauseImg = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: "Pause")?.withSymbolConfiguration(playPauseConfig)
        playPauseButton.image = playPauseImg
        playPauseButton.isBordered = false
        playPauseButton.setButtonType(.momentaryChange)
        playPauseButton.contentTintColor = .labelColor
        playPauseButton.frame = NSRect(x: 52, y: 41, width: 40, height: 26)
        playPauseButton.target = self
        playPauseButton.action = #selector(playPauseClicked(_:))
        addSubview(playPauseButton)
        
        let nextImg = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: "Next Track")?.withSymbolConfiguration(navConfig)
        nextButton.image = nextImg
        nextButton.isBordered = false
        nextButton.setButtonType(.momentaryChange)
        nextButton.contentTintColor = .labelColor
        nextButton.frame = NSRect(x: 102, y: 42, width: 34, height: 24)
        nextButton.target = self
        nextButton.action = #selector(nextClicked(_:))
        addSubview(nextButton)
        
        // Single Custom Translate SVG Icon Button (Towards Right) - Toggles between Original and Romanized Lyrics
        translateButton.image = translateIcon
        translateButton.isBordered = false
        translateButton.setButtonType(.momentaryChange)
        translateButton.contentTintColor = .labelColor
        translateButton.frame = NSRect(x: 174, y: 41, width: 26, height: 26)
        translateButton.target = self
        translateButton.action = #selector(translateClicked(_:))
        addSubview(translateButton)
        
        // 5. Row 4 (Bottom): Playback Progress Scroll Bar & Timeline Labels
        elapsedLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .medium)
        elapsedLabel.textColor = .secondaryLabelColor
        elapsedLabel.alignment = .left
        elapsedLabel.frame = NSRect(x: 8, y: 71, width: 28, height: 12)
        addSubview(elapsedLabel)
        
        progressSlider.cell = CustomProgressSliderCell()
        progressSlider.controlSize = .mini
        progressSlider.frame = NSRect(x: 37, y: 69, width: 136, height: 16)
        progressSlider.isContinuous = true
        progressSlider.target = self
        progressSlider.action = #selector(sliderChanged(_:))
        let electricBlue = NSColor(red: 0.0 / 255.0, green: 136.0 / 255.0, blue: 255.0 / 255.0, alpha: 1.0)
        if #available(macOS 15.0, *) {
            progressSlider.trackFillColor = electricBlue
        }
        if #available(macOS 26.0, *) {
            progressSlider.tintProminence = .primary
        }
        addSubview(progressSlider)
        
        durationLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .medium)
        durationLabel.textColor = .secondaryLabelColor
        durationLabel.alignment = .right
        durationLabel.frame = NSRect(x: 174, y: 71, width: 28, height: 12)
        addSubview(durationLabel)
        
        updateModeVisuals()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setProgress(position: Double, duration: Double) {
        guard !isUserSeeking, Date().timeIntervalSince(lastSeekTimestamp) > 1.5 else { return }
        let validDuration = (duration > 0 && !duration.isNaN && !duration.isInfinite) ? duration : 1.0
        let validPosition = (position >= 0 && !position.isNaN && !position.isInfinite) ? min(position, validDuration) : 0.0
        
        progressSlider.minValue = 0.0
        progressSlider.maxValue = validDuration
        progressSlider.doubleValue = validPosition
        
        elapsedLabel.stringValue = formatTime(validPosition)
        durationLabel.stringValue = formatTime(validDuration)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    @objc private func sliderChanged(_ sender: NSSlider) {
        let currentEvent = NSApplication.shared.currentEvent
        let isMouseUp = (currentEvent?.type == .leftMouseUp)
        
        // Update elapsed time label locally at 60fps
        elapsedLabel.stringValue = formatTime(sender.doubleValue)
        
        if isMouseUp {
            isUserSeeking = false
            lastSeekTimestamp = Date()
            seekHandler?(sender.doubleValue)
        } else {
            isUserSeeking = true
        }
    }
    
    @objc private func openBuyMeACoffee(_ sender: NSButton) {
        if let url = URL(string: "https://dai-ski.github.io/LYRA/#") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func setMode(_ mode: LyricMode) {
        self.currentMode = mode
        updateModeVisuals()
    }
    
    func setTrackTitle(_ title: String, artist: String = "") {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanTitle.isEmpty {
            songTitleLabel.stringValue = ""
        } else if !cleanArtist.isEmpty {
            songTitleLabel.stringValue = "\(cleanTitle) • \(cleanArtist)"
        } else {
            songTitleLabel.stringValue = cleanTitle
        }
    }
    
    private func updateModeVisuals() {
        translateButton.alphaValue = (currentMode == .romanized) ? 1.0 : 0.60
    }
    
    @objc private func translateClicked(_ sender: NSButton) {
        let nextMode: LyricMode = (currentMode == .original) ? .romanized : .original
        setMode(nextMode)
        modeChangeHandler?(nextMode)
    }
    
    func setPlaybackState(isPlaying: Bool) {
        let symbolName = isPlaying ? "pause.fill" : "play.fill"
        let playPauseConfig = NSImage.SymbolConfiguration(pointSize: 17, weight: .bold)
        let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: isPlaying ? "Pause" : "Play")?.withSymbolConfiguration(playPauseConfig)
        playPauseButton.image = img
    }
    
    func setLyricsState(areLyricsEnabled: Bool) {
        trafficLights.areLyricsEnabled = areLyricsEnabled
    }
    
    @objc private func prevClicked(_ sender: NSButton) {
        previousTrackHandler?()
    }
    
    @objc private func playPauseClicked(_ sender: NSButton) {
        playPauseHandler?()
    }
    
    @objc private func nextClicked(_ sender: NSButton) {
        nextTrackHandler?()
    }
}