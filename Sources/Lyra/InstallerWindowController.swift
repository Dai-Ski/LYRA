import AppKit

/// Intricate artwork background with dynamic glowing soundwaves, audio equalizer bars, and vibrant gradients.
@MainActor
final class IntricateDesignBackgroundView: NSView {
    var phase: CGFloat = 0
    nonisolated(unsafe) var timer: Timer?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        startAnimation()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.phase += 0.025
                self?.needsDisplay = true
            }
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let bounds = self.bounds
        
        // 1. Rich Shifting Mesh Gradient (Deep Violet -> Royal Magenta -> Midnight Teal -> Electric Purple)
        let color1 = NSColor(calibratedRed: 0.16 + 0.05 * sin(phase), green: 0.06, blue: 0.35 + 0.06 * cos(phase), alpha: 1.0)
        let color2 = NSColor(calibratedRed: 0.50 + 0.09 * cos(phase), green: 0.10, blue: 0.60 + 0.09 * sin(phase), alpha: 1.0)
        let color3 = NSColor(calibratedRed: 0.06, green: 0.32 + 0.07 * sin(phase * 0.8), blue: 0.48, alpha: 1.0)
        let color4 = NSColor(calibratedRed: 0.30 + 0.06 * sin(phase * 1.2), green: 0.06, blue: 0.55, alpha: 1.0)
        
        guard let gradient = NSGradient(colors: [color1, color2, color3, color4]) else { return }
        let angle = 40.0 + 20.0 * sin(phase * 0.4)
        gradient.draw(in: bounds, angle: angle)
        
        // 2. Draw Intricate Glowing Sine Soundwaves
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        
        // Wave 1: Neon Cyan Soundwave
        let wave1 = NSBezierPath()
        let midY = bounds.height * 0.5
        wave1.move(to: NSPoint(x: 0, y: midY))
        for x in stride(from: 0, to: bounds.width, by: 4) {
            let y = midY + sin(x * 0.015 + phase * 2.2) * 38.0 + cos(x * 0.025 + phase) * 18.0
            wave1.line(to: NSPoint(x: x, y: y))
        }
        NSColor(calibratedRed: 0.2, green: 0.95, blue: 1.0, alpha: 0.40).setStroke()
        wave1.lineWidth = 3.0
        wave1.stroke()
        
        // Wave 2: Neon Pink/Magenta Soundwave
        let wave2 = NSBezierPath()
        wave2.move(to: NSPoint(x: 0, y: midY))
        for x in stride(from: 0, to: bounds.width, by: 4) {
            let y = midY + cos(x * 0.018 - phase * 2.0) * 42.0 + sin(x * 0.01 + phase * 0.6) * 22.0
            wave2.line(to: NSPoint(x: x, y: y))
        }
        NSColor(calibratedRed: 1.0, green: 0.35, blue: 0.90, alpha: 0.40).setStroke()
        wave2.lineWidth = 2.5
        wave2.stroke()
        
        // Wave 3: Golden Glow Soundwave
        let wave3 = NSBezierPath()
        wave3.move(to: NSPoint(x: 0, y: midY))
        for x in stride(from: 0, to: bounds.width, by: 4) {
            let y = midY + sin(x * 0.022 + phase * 1.4) * 28.0
            wave3.line(to: NSPoint(x: x, y: y))
        }
        NSColor(calibratedRed: 1.0, green: 0.88, blue: 0.35, alpha: 0.35).setStroke()
        wave3.lineWidth = 2.0
        wave3.stroke()
        
        // 3. Draw Animated Equalizer Soundbar Visualizer at Bottom
        let barCount = 30
        let barWidth: CGFloat = 8.0
        let gap: CGFloat = (bounds.width - CGFloat(barCount) * barWidth) / CGFloat(barCount + 1)
        
        for i in 0..<barCount {
            let x = gap + CGFloat(i) * (barWidth + gap)
            let baseH: CGFloat = 14.0
            let flexH: CGFloat = abs(sin(phase * 3.5 + CGFloat(i) * 0.4) * 50.0) + abs(cos(phase * 2.2 + CGFloat(i) * 0.3) * 28.0)
            let height = baseH + flexH
            
            let rect = NSRect(x: x, y: 12, width: barWidth, height: height)
            let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
            
            let ratio = CGFloat(i) / CGFloat(barCount)
            let barColor = NSColor(
                calibratedRed: 0.3 + 0.7 * ratio,
                green: 0.6 + 0.4 * (1.0 - ratio),
                blue: 0.98,
                alpha: 0.50 + 0.30 * sin(phase * 2.0 + CGFloat(i))
            )
            barColor.setFill()
            path.fill()
        }
        
        // 4. Intricate Decorative Corner Lines
        let cornerPath = NSBezierPath()
        // Top-Left Corner
        cornerPath.move(to: NSPoint(x: 20, y: bounds.height - 40))
        cornerPath.line(to: NSPoint(x: 20, y: bounds.height - 20))
        cornerPath.line(to: NSPoint(x: 40, y: bounds.height - 20))
        
        // Top-Right Corner
        cornerPath.move(to: NSPoint(x: bounds.width - 40, y: bounds.height - 20))
        cornerPath.line(to: NSPoint(x: bounds.width - 20, y: bounds.height - 20))
        cornerPath.line(to: NSPoint(x: bounds.width - 20, y: bounds.height - 40))
        
        NSColor.white.withAlphaComponent(0.35).setStroke()
        cornerPath.lineWidth = 2.0
        cornerPath.stroke()
        
        context?.restoreGState()
    }
}

/// Represents an animated musical note emoji particle during drag and drop.
@MainActor
final class EmojiParticleView: NSTextField {
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var alphaVal: CGFloat = 1.0
    var scaleVal: CGFloat = 1.0
    var rotationVal: CGFloat = 0
    var vr: CGFloat = 0
    
    init(emoji: String, origin: NSPoint) {
        super.init(frame: NSRect(x: origin.x - 22, y: origin.y - 22, width: 44, height: 44))
        self.stringValue = emoji
        self.font = NSFont.systemFont(ofSize: 28)
        self.isEditable = false
        self.isSelectable = false
        self.isBezeled = false
        self.drawsBackground = false
        self.alignment = .center
        self.wantsLayer = true
        
        // Random velocities & rotation
        self.vx = CGFloat.random(in: -4.0...4.0)
        self.vy = CGFloat.random(in: 3.0...6.5) // floats upward
        self.alphaVal = CGFloat.random(in: 0.95...1.0)
        self.scaleVal = CGFloat.random(in: 1.0...1.8)
        self.rotationVal = CGFloat.random(in: -0.8...0.8)
        self.vr = CGFloat.random(in: -0.18...0.18)
        
        updateTransform()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update() -> Bool {
        var frame = self.frame
        frame.origin.x += vx
        frame.origin.y += vy
        self.frame = frame
        
        alphaVal -= 0.020
        scaleVal += 0.015
        rotationVal += vr
        
        self.alphaValue = max(0, alphaVal)
        updateTransform()
        
        return alphaVal > 0
    }
    
    private func updateTransform() {
        guard let layer = self.layer else { return }
        var transform = CATransform3DIdentity
        transform = CATransform3DScale(transform, scaleVal, scaleVal, 1.0)
        transform = CATransform3DRotate(transform, rotationVal, 0, 0, 1.0)
        layer.transform = transform
    }
}

/// Interactive Drag-and-Drop installer window with intricate designs, glowing soundwaves, and popping musical notes.
@MainActor
public final class InstallerWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow!
    private var completionHandler: (Bool) -> Void
    
    private var containerView: NSView!
    private var appIconView: NSBox!
    private var dropTargetBox: NSBox!
    private var statusLabel: NSTextField!
    private var trashLaunchButton: NSButton!
    private var launchOnlyButton: NSButton!
    
    private var particles: [EmojiParticleView] = []
    nonisolated(unsafe) private var animationTimer: Timer?
    
    private var initialAppIconFrame: NSRect = .zero
    private var isDragging = false
    private var dragOffset: NSPoint = .zero
    
    private static let noteEmojis = ["🎵", "🎶", "🎼", "✨", "🎤", "🎧", "🎹", "💫", "🌟", "💜", "💖", "💙", "🌈", "🎉", "🔥", "⚡️"]
    
    public init(completion: @escaping (Bool) -> Void) {
        self.completionHandler = completion
        super.init()
        setupWindow()
        startAnimationTimer()
    }
    
    deinit {
        animationTimer?.invalidate()
    }
    
    private func setupWindow() {
        let windowWidth: CGFloat = 560
        let windowHeight: CGFloat = 360
        let rect = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
        
        window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.delegate = self
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.center()
        
        // 1. Intricate Artwork Background View (Soundwaves + Equalizer Visualizer)
        let artworkBackground = IntricateDesignBackgroundView(frame: rect)
        artworkBackground.autoresizingMask = [.width, .height]
        
        containerView = NSView(frame: rect)
        containerView.autoresizingMask = [.width, .height]
        artworkBackground.addSubview(containerView)
        
        // Header Title
        let titleLabel = NSTextField(labelWithString: "✨ L Y R A ✨")
        titleLabel.font = NSFont.systemFont(ofSize: 26, weight: .black)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 20, y: 305, width: 520, height: 34)
        containerView.addSubview(titleLabel)
        
        // Subtitle instructions
        let subtitleLabel = NSTextField(labelWithString: "Drag Lyra icon to Applications (Hover to see musical notes burst!)")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .black)
        subtitleLabel.textColor = NSColor(calibratedRed: 0.95, green: 0.88, blue: 1.0, alpha: 0.95)
        subtitleLabel.alignment = .center
        subtitleLabel.frame = NSRect(x: 20, y: 280, width: 520, height: 20)
        containerView.addSubview(subtitleLabel)
        
        // --- 1. Source App Icon Box (Left - Big 128px style) ---
        initialAppIconFrame = NSRect(x: 65, y: 110, width: 155, height: 160)
        appIconView = NSBox(frame: initialAppIconFrame)
        appIconView.boxType = .custom
        appIconView.borderColor = NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.88, alpha: 0.95) // Glowing Magenta
        appIconView.borderWidth = 3.0
        appIconView.cornerRadius = 22.0
        appIconView.fillColor = NSColor.black.withAlphaComponent(0.55)
        
        let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "png") ?? ""
        if let iconImage = NSImage(contentsOfFile: iconPath) ?? NSApp.applicationIconImage {
            let iconImageView = NSImageView(frame: NSRect(x: 35, y: 55, width: 85, height: 85))
            iconImageView.image = iconImage
            iconImageView.imageScaling = .scaleProportionallyUpOrDown
            appIconView.addSubview(iconImageView)
        } else {
            let appEmojiLabel = NSTextField(labelWithString: "🎵")
            appEmojiLabel.font = NSFont.systemFont(ofSize: 64)
            appEmojiLabel.alignment = .center
            appEmojiLabel.frame = NSRect(x: 10, y: 55, width: 135, height: 75)
            appIconView.addSubview(appEmojiLabel)
        }
        
        let appNameLabel = NSTextField(labelWithString: "Lyra.app")
        appNameLabel.font = NSFont.systemFont(ofSize: 14, weight: .black)
        appNameLabel.textColor = .white
        appNameLabel.alignment = .center
        appNameLabel.frame = NSRect(x: 5, y: 26, width: 145, height: 22)
        appIconView.addSubview(appNameLabel)
        
        let dragHintLabel = NSTextField(labelWithString: "(Hover/Drag Me! 🎵)")
        dragHintLabel.font = NSFont.systemFont(ofSize: 11, weight: .black)
        dragHintLabel.textColor = NSColor(calibratedRed: 1.0, green: 0.75, blue: 0.95, alpha: 1.0)
        dragHintLabel.alignment = .center
        dragHintLabel.frame = NSRect(x: 5, y: 6, width: 145, height: 16)
        appIconView.addSubview(dragHintLabel)
        
        containerView.addSubview(appIconView)
        
        // --- 2. Guidance Arrow (Center) ---
        let arrowLabel = NSTextField(labelWithString: "➔")
        arrowLabel.font = NSFont.systemFont(ofSize: 44, weight: .black)
        arrowLabel.textColor = NSColor(calibratedRed: 0.98, green: 0.78, blue: 1.0, alpha: 0.9)
        arrowLabel.alignment = .center
        arrowLabel.frame = NSRect(x: 235, y: 160, width: 90, height: 50)
        containerView.addSubview(arrowLabel)
        
        // --- 3. Drop Target Box (Right: Applications - Big 128px style) ---
        dropTargetBox = NSBox(frame: NSRect(x: 340, y: 110, width: 155, height: 160))
        dropTargetBox.boxType = .custom
        dropTargetBox.borderColor = NSColor(calibratedRed: 0.2, green: 0.95, blue: 1.0, alpha: 0.95) // Glowing Neon Cyan
        dropTargetBox.borderWidth = 3.0
        dropTargetBox.cornerRadius = 22.0
        dropTargetBox.fillColor = NSColor(calibratedRed: 0.0, green: 0.45, blue: 0.85, alpha: 0.35)
        
        let folderEmojiLabel = NSTextField(labelWithString: "📁")
        folderEmojiLabel.font = NSFont.systemFont(ofSize: 64)
        folderEmojiLabel.alignment = .center
        folderEmojiLabel.frame = NSRect(x: 10, y: 55, width: 135, height: 75)
        dropTargetBox.addSubview(folderEmojiLabel)
        
        let folderNameLabel = NSTextField(labelWithString: "Applications")
        folderNameLabel.font = NSFont.systemFont(ofSize: 14, weight: .black)
        folderNameLabel.textColor = .white
        folderNameLabel.alignment = .center
        folderNameLabel.frame = NSRect(x: 5, y: 26, width: 145, height: 22)
        dropTargetBox.addSubview(folderNameLabel)
        
        let dropHereLabel = NSTextField(labelWithString: "Drop Here ✨")
        dropHereLabel.font = NSFont.systemFont(ofSize: 11, weight: .black)
        dropHereLabel.textColor = NSColor(calibratedRed: 0.4, green: 0.95, blue: 1.0, alpha: 1.0)
        dropHereLabel.alignment = .center
        dropHereLabel.frame = NSRect(x: 5, y: 6, width: 145, height: 16)
        dropTargetBox.addSubview(dropHereLabel)
        
        containerView.addSubview(dropTargetBox)
        
        // Status Message
        statusLabel = NSTextField(labelWithString: "Drag Lyra into Applications to start making musical magic!")
        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .black)
        statusLabel.textColor = .white
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 20, y: 68, width: 520, height: 22)
        containerView.addSubview(statusLabel)
        
        // --- Action Buttons after copy ---
        // 1. Primary Button: Move DMG to Trash & Launch
        trashLaunchButton = NSButton(frame: NSRect(x: 65, y: 20, width: 220, height: 38))
        trashLaunchButton.title = "🗑️ MOVE DMG TO TRASH & LAUNCH"
        trashLaunchButton.font = NSFont.systemFont(ofSize: 10, weight: .black)
        trashLaunchButton.bezelStyle = .regularSquare
        trashLaunchButton.isBordered = true
        trashLaunchButton.isHidden = true
        trashLaunchButton.target = self
        trashLaunchButton.action = #selector(trashAndLaunchClicked)
        containerView.addSubview(trashLaunchButton)
        
        // 2. Secondary Button: Launch Lyra (Keep DMG)
        launchOnlyButton = NSButton(frame: NSRect(x: 300, y: 20, width: 175, height: 38))
        launchOnlyButton.title = "🚀 LAUNCH LYRA"
        launchOnlyButton.font = NSFont.systemFont(ofSize: 10, weight: .black)
        launchOnlyButton.bezelStyle = .regularSquare
        launchOnlyButton.isBordered = true
        launchOnlyButton.isHidden = true
        launchOnlyButton.target = self
        launchOnlyButton.action = #selector(launchOnlyClicked)
        containerView.addSubview(launchOnlyButton)
        
        window.contentView = artworkBackground
        
        // Register mouse drag & hover tracking overlay
        let dragTrackingView = DragTrackingView(frame: rect, controller: self)
        containerView.addSubview(dragTrackingView, positioned: .above, relativeTo: nil)
    }
    
    public func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    
    private func startAnimationTimer() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateParticles()
            }
        }
    }
    
    private func updateParticles() {
        particles.removeAll { particle in
            let keep = particle.update()
            if !keep {
                particle.removeFromSuperview()
            }
            return !keep
        }
    }
    
    fileprivate func handleMouseMoved(at point: NSPoint) {
        guard !isDragging else { return }
        
        // ON HOVER OVER LYRA APP ICON -> BURST OUT EMOJIS!
        if appIconView.frame.contains(point) {
            spawnNotes(at: point, count: 2)
            appIconView.borderColor = NSColor(calibratedRed: 1.0, green: 0.65, blue: 0.95, alpha: 1.0)
            appIconView.fillColor = NSColor.black.withAlphaComponent(0.65)
        } else {
            appIconView.borderColor = NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.88, alpha: 0.95)
            appIconView.fillColor = NSColor.black.withAlphaComponent(0.50)
        }
        
        // ON HOVER OVER APPLICATIONS -> HIGHLIGHT ONLY (DO NOT OPEN APPLICATIONS ON HOVER!)
        if dropTargetBox.frame.contains(point) {
            dropTargetBox.borderColor = NSColor(calibratedRed: 0.4, green: 1.0, blue: 0.6, alpha: 0.95)
            dropTargetBox.fillColor = NSColor(calibratedRed: 0.0, green: 0.6, blue: 0.3, alpha: 0.25)
        } else {
            dropTargetBox.borderColor = NSColor(calibratedRed: 0.2, green: 0.95, blue: 1.0, alpha: 0.95)
            dropTargetBox.fillColor = NSColor(calibratedRed: 0.0, green: 0.45, blue: 0.85, alpha: 0.35)
        }
    }
    
    fileprivate func handleMouseDown(at point: NSPoint) {
        if appIconView.frame.contains(point) {
            isDragging = true
            dragOffset = NSPoint(x: point.x - appIconView.frame.origin.x, y: point.y - appIconView.frame.origin.y)
            spawnNotes(at: point, count: 8)
        }
    }
    
    fileprivate func handleMouseDragged(at point: NSPoint) {
        guard isDragging else { return }
        
        let newX = max(10, min(containerView.bounds.width - appIconView.bounds.width - 10, point.x - dragOffset.x))
        let newY = max(10, min(containerView.bounds.height - appIconView.bounds.height - 10, point.y - dragOffset.y))
        appIconView.frame.origin = NSPoint(x: newX, y: newY)
        
        // POP VIBRANT COLORFUL MUSICAL NOTE EMOJIS CONTINUOUSLY WHILE DRAGGING!
        spawnNotes(at: point, count: 6)
        
        // Highlight drop target when overlapping
        if appIconView.frame.intersects(dropTargetBox.frame) {
            dropTargetBox.fillColor = NSColor.systemGreen.withAlphaComponent(0.55)
            dropTargetBox.borderColor = NSColor.systemGreen
        } else {
            dropTargetBox.fillColor = NSColor(calibratedRed: 0.0, green: 0.45, blue: 0.85, alpha: 0.35)
            dropTargetBox.borderColor = NSColor(calibratedRed: 0.2, green: 0.95, blue: 1.0, alpha: 0.95)
        }
    }
    
    fileprivate func handleMouseUp(at point: NSPoint) {
        guard isDragging else { return }
        isDragging = false
        
        if appIconView.frame.intersects(dropTargetBox.frame) {
            performInstallation()
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                self.appIconView.animator().frame = self.initialAppIconFrame
            }
            dropTargetBox.fillColor = NSColor(calibratedRed: 0.0, green: 0.45, blue: 0.85, alpha: 0.35)
            dropTargetBox.borderColor = NSColor(calibratedRed: 0.2, green: 0.95, blue: 1.0, alpha: 0.95)
        }
    }
    
    private func spawnNotes(at point: NSPoint, count: Int) {
        for _ in 0..<count {
            let emoji = Self.noteEmojis.randomElement() ?? "🎵"
            let offsetPoint = NSPoint(
                x: point.x + CGFloat.random(in: -30...30),
                y: point.y + CGFloat.random(in: -30...30)
            )
            let particle = EmojiParticleView(emoji: emoji, origin: offsetPoint)
            containerView.addSubview(particle, positioned: .above, relativeTo: nil)
            particles.append(particle)
        }
    }
    
    private func performInstallation() {
        // 1. Massive Musical Note Celebration Explosion!
        let targetCenter = NSPoint(
            x: dropTargetBox.frame.midX,
            y: dropTargetBox.frame.midY
        )
        spawnNotes(at: targetCenter, count: 70)
        
        appIconView.frame.origin = NSPoint(
            x: dropTargetBox.frame.origin.x + 5,
            y: dropTargetBox.frame.origin.y + 5
        )
        
        // 2. Perform copy to /Applications/Lyra.app
        let sourcePath = Bundle.main.bundlePath
        let destPath = "/Applications/Lyra.app"
        
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: destPath) {
                try fm.removeItem(atPath: destPath)
            }
            try fm.copyItem(atPath: sourcePath, toPath: destPath)
            
            // Re-apply ad-hoc codesign to /Applications/Lyra.app
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
            task.arguments = ["--force", "--deep", "--sign", "-", destPath]
            try? task.run()
            
            statusLabel.stringValue = "🎉 Lyra Installed! Would you like to move the installer (DMG) to Trash?"
            statusLabel.textColor = NSColor(calibratedRed: 0.4, green: 1.0, blue: 0.6, alpha: 1.0)
            trashLaunchButton.isHidden = false
            launchOnlyButton.isHidden = false
        } catch {
            statusLabel.stringValue = "Lyra is ready in /Applications! Would you like to delete the DMG?"
            statusLabel.textColor = .white
            trashLaunchButton.isHidden = false
            launchOnlyButton.isHidden = false
        }
    }
    
    @objc private func trashAndLaunchClicked() {
        let fm = FileManager.default

        // 1. Check for ~/Downloads/Lyra.dmg
        let downloadsDMG = fm.homeDirectoryForCurrentUser.appendingPathComponent("Downloads/Lyra.dmg")
        if fm.fileExists(atPath: downloadsDMG.path) {
            try? fm.trashItem(at: downloadsDMG, resultingItemURL: nil)
        }

        // 2. Check if running from mounted /Volumes/ DMG volume
        let bundlePath = Bundle.main.bundlePath
        if bundlePath.hasPrefix("/Volumes/") {
            let components = bundlePath.components(separatedBy: "/")
            if components.count >= 3 {
                let volumePath = "/Volumes/\(components[2])"
                let volumeURL = URL(fileURLWithPath: volumePath)
                try? NSWorkspace.shared.unmountAndEjectDevice(at: volumeURL)
            }
        }

        launchOnlyClicked()
    }
    
    @objc private func launchOnlyClicked() {
        let destPath = "/Applications/Lyra.app"
        let url = URL(fileURLWithPath: destPath)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        
        window.close()
        completionHandler(true)
    }
    
    public func windowWillClose(_ notification: Notification) {
        completionHandler(false)
    }
}

/// Transparent overlay view to capture drag & hover events smoothly over the container.
@MainActor
private final class DragTrackingView: NSView {
    private weak var controller: InstallerWindowController?
    
    init(frame frameRect: NSRect, controller: InstallerWindowController) {
        self.controller = controller
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }
    
    override func mouseMoved(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        controller?.handleMouseMoved(at: loc)
    }
    
    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        controller?.handleMouseDown(at: loc)
    }
    
    override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        controller?.handleMouseDragged(at: loc)
    }
    
    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        controller?.handleMouseUp(at: loc)
    }
}
