import AppKit

/// Animated colorful background view with slow shifting neon purple/magenta/cyan gradient.
@MainActor
final class ColorfulGradientView: NSView {
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
                self?.phase += 0.015
                self?.needsDisplay = true
            }
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let color1 = NSColor(calibratedRed: 0.14 + 0.04 * sin(phase), green: 0.06, blue: 0.32 + 0.06 * cos(phase), alpha: 1.0)
        let color2 = NSColor(calibratedRed: 0.42 + 0.08 * cos(phase), green: 0.10, blue: 0.52 + 0.08 * sin(phase), alpha: 1.0)
        let color3 = NSColor(calibratedRed: 0.06, green: 0.28 + 0.06 * sin(phase * 0.8), blue: 0.46, alpha: 1.0)
        
        guard let gradient = NSGradient(colors: [color1, color2, color3]) else { return }
        let angle = 45.0 + 15.0 * sin(phase * 0.5)
        gradient.draw(in: bounds, angle: angle)
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
        super.init(frame: NSRect(x: origin.x - 18, y: origin.y - 18, width: 36, height: 36))
        self.stringValue = emoji
        self.font = NSFont.systemFont(ofSize: 24)
        self.isEditable = false
        self.isSelectable = false
        self.isBezeled = false
        self.drawsBackground = false
        self.alignment = .center
        self.wantsLayer = true
        
        // Random velocities & rotation
        self.vx = CGFloat.random(in: -3.0...3.0)
        self.vy = CGFloat.random(in: 2.0...5.0) // floats upward
        self.alphaVal = CGFloat.random(in: 0.9...1.0)
        self.scaleVal = CGFloat.random(in: 0.8...1.6)
        self.rotationVal = CGFloat.random(in: -0.6...0.6)
        self.vr = CGFloat.random(in: -0.12...0.12)
        
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
        scaleVal += 0.010
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

/// Interactive Drag-and-Drop installer window with colorful gradient background and popping musical note emojis.
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
        let windowWidth: CGFloat = 600
        let windowHeight: CGFloat = 380
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
        
        // 1. Vibrant Animated Colorful Gradient Background
        let gradientBackground = ColorfulGradientView(frame: rect)
        gradientBackground.autoresizingMask = [.width, .height]
        
        // 2. Glassmorphism Visual Effect Overlay
        let visualEffectView = NSVisualEffectView(frame: rect)
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.autoresizingMask = [.width, .height]
        gradientBackground.addSubview(visualEffectView)
        
        containerView = NSView(frame: rect)
        containerView.autoresizingMask = [.width, .height]
        visualEffectView.addSubview(containerView)
        
        // Window Title
        let titleLabel = NSTextField(labelWithString: "✨ L Y R A ✨")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .black)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 20, y: 318, width: 560, height: 32)
        containerView.addSubview(titleLabel)
        
        // Subtitle instructions
        let subtitleLabel = NSTextField(labelWithString: "Drag Lyra into Applications to complete installation")
        subtitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        subtitleLabel.textColor = NSColor(calibratedRed: 0.9, green: 0.85, blue: 1.0, alpha: 0.9)
        subtitleLabel.alignment = .center
        subtitleLabel.frame = NSRect(x: 20, y: 292, width: 560, height: 22)
        containerView.addSubview(subtitleLabel)
        
        // --- 1. Source App Icon Box (Left) ---
        initialAppIconFrame = NSRect(x: 85, y: 125, width: 140, height: 148)
        appIconView = NSBox(frame: initialAppIconFrame)
        appIconView.boxType = .custom
        appIconView.borderColor = NSColor(calibratedRed: 0.95, green: 0.45, blue: 0.85, alpha: 0.8) // Glowing Pink/Purple
        appIconView.borderWidth = 2.0
        appIconView.cornerRadius = 18.0
        appIconView.fillColor = NSColor.black.withAlphaComponent(0.40)
        
        let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "png") ?? ""
        if let iconImage = NSImage(contentsOfFile: iconPath) ?? NSApp.applicationIconImage {
            let iconImageView = NSImageView(frame: NSRect(x: 38, y: 62, width: 64, height: 64))
            iconImageView.image = iconImage
            iconImageView.imageScaling = .scaleProportionallyUpOrDown
            appIconView.addSubview(iconImageView)
        } else {
            let appEmojiLabel = NSTextField(labelWithString: "🎵")
            appEmojiLabel.font = NSFont.systemFont(ofSize: 52)
            appEmojiLabel.alignment = .center
            appEmojiLabel.frame = NSRect(x: 10, y: 60, width: 120, height: 60)
            appIconView.addSubview(appEmojiLabel)
        }
        
        let appNameLabel = NSTextField(labelWithString: "Lyra.app")
        appNameLabel.font = NSFont.systemFont(ofSize: 13, weight: .heavy)
        appNameLabel.textColor = .white
        appNameLabel.alignment = .center
        appNameLabel.frame = NSRect(x: 5, y: 24, width: 130, height: 22)
        appIconView.addSubview(appNameLabel)
        
        let dragHintLabel = NSTextField(labelWithString: "(Drag Me! 🎵)")
        dragHintLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        dragHintLabel.textColor = NSColor(calibratedRed: 1.0, green: 0.7, blue: 0.9, alpha: 0.95)
        dragHintLabel.alignment = .center
        dragHintLabel.frame = NSRect(x: 5, y: 6, width: 130, height: 16)
        appIconView.addSubview(dragHintLabel)
        
        containerView.addSubview(appIconView)
        
        // --- 2. Guidance Arrow (Center) ---
        let arrowLabel = NSTextField(labelWithString: "➔")
        arrowLabel.font = NSFont.systemFont(ofSize: 42, weight: .black)
        arrowLabel.textColor = NSColor(calibratedRed: 0.9, green: 0.7, blue: 1.0, alpha: 0.7)
        arrowLabel.alignment = .center
        arrowLabel.frame = NSRect(x: 250, y: 172, width: 100, height: 50)
        containerView.addSubview(arrowLabel)
        
        // --- 3. Drop Target Box (Right: Applications) ---
        dropTargetBox = NSBox(frame: NSRect(x: 375, y: 125, width: 140, height: 148))
        dropTargetBox.boxType = .custom
        dropTargetBox.borderColor = NSColor(calibratedRed: 0.2, green: 0.85, blue: 0.95, alpha: 0.8) // Glowing Cyan
        dropTargetBox.borderWidth = 2.5
        dropTargetBox.cornerRadius = 18.0
        dropTargetBox.fillColor = NSColor(calibratedRed: 0.0, green: 0.4, blue: 0.8, alpha: 0.25)
        
        let folderEmojiLabel = NSTextField(labelWithString: "📁")
        folderEmojiLabel.font = NSFont.systemFont(ofSize: 52)
        folderEmojiLabel.alignment = .center
        folderEmojiLabel.frame = NSRect(x: 10, y: 60, width: 120, height: 60)
        dropTargetBox.addSubview(folderEmojiLabel)
        
        let folderNameLabel = NSTextField(labelWithString: "Applications")
        folderNameLabel.font = NSFont.systemFont(ofSize: 13, weight: .heavy)
        folderNameLabel.textColor = .white
        folderNameLabel.alignment = .center
        folderNameLabel.frame = NSRect(x: 5, y: 24, width: 130, height: 22)
        dropTargetBox.addSubview(folderNameLabel)
        
        let dropHereLabel = NSTextField(labelWithString: "Drop Here ✨")
        dropHereLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        dropHereLabel.textColor = NSColor(calibratedRed: 0.4, green: 0.9, blue: 1.0, alpha: 0.95)
        dropHereLabel.alignment = .center
        dropHereLabel.frame = NSRect(x: 5, y: 6, width: 130, height: 16)
        dropTargetBox.addSubview(dropHereLabel)
        
        containerView.addSubview(dropTargetBox)
        
        // Status message
        statusLabel = NSTextField(labelWithString: "Drag Lyra into Applications to start making musical magic!")
        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        statusLabel.textColor = NSColor.white.withAlphaComponent(0.85)
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 20, y: 72, width: 560, height: 24)
        containerView.addSubview(statusLabel)
        
        // --- Action Buttons after copy ---
        // 1. Primary Button: Move DMG to Trash & Launch
        trashLaunchButton = NSButton(frame: NSRect(x: 90, y: 22, width: 230, height: 38))
        trashLaunchButton.title = "🗑️ MOVE DMG TO TRASH & LAUNCH"
        trashLaunchButton.font = NSFont.systemFont(ofSize: 10, weight: .black)
        trashLaunchButton.bezelStyle = .regularSquare
        trashLaunchButton.isBordered = true
        trashLaunchButton.isHidden = true
        trashLaunchButton.target = self
        trashLaunchButton.action = #selector(trashAndLaunchClicked)
        containerView.addSubview(trashLaunchButton)
        
        // 2. Secondary Button: Launch Lyra (Keep DMG)
        launchOnlyButton = NSButton(frame: NSRect(x: 335, y: 22, width: 175, height: 38))
        launchOnlyButton.title = "🚀 LAUNCH LYRA"
        launchOnlyButton.font = NSFont.systemFont(ofSize: 10, weight: .black)
        launchOnlyButton.bezelStyle = .regularSquare
        launchOnlyButton.isBordered = true
        launchOnlyButton.isHidden = true
        launchOnlyButton.target = self
        launchOnlyButton.action = #selector(launchOnlyClicked)
        containerView.addSubview(launchOnlyButton)
        
        window.contentView = gradientBackground
        
        // Register mouse drag tracking overlay
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
    
    fileprivate func handleMouseDown(at point: NSPoint) {
        if appIconView.frame.contains(point) {
            isDragging = true
            dragOffset = NSPoint(x: point.x - appIconView.frame.origin.x, y: point.y - appIconView.frame.origin.y)
            spawnNotes(at: point, count: 6)
        }
    }
    
    fileprivate func handleMouseDragged(at point: NSPoint) {
        guard isDragging else { return }
        
        let newX = max(10, min(containerView.bounds.width - appIconView.bounds.width - 10, point.x - dragOffset.x))
        let newY = max(10, min(containerView.bounds.height - appIconView.bounds.height - 10, point.y - dragOffset.y))
        appIconView.frame.origin = NSPoint(x: newX, y: newY)
        
        // POP VIBRANT COLORFUL MUSICAL NOTE EMOJIS CONTINUOUSLY WHILE DRAGGING!
        spawnNotes(at: point, count: 4)
        
        // Highlight drop target when overlapping
        if appIconView.frame.intersects(dropTargetBox.frame) {
            dropTargetBox.fillColor = NSColor.systemGreen.withAlphaComponent(0.45)
            dropTargetBox.borderColor = NSColor.systemGreen
        } else {
            dropTargetBox.fillColor = NSColor(calibratedRed: 0.0, green: 0.4, blue: 0.8, alpha: 0.25)
            dropTargetBox.borderColor = NSColor(calibratedRed: 0.2, green: 0.85, blue: 0.95, alpha: 0.8)
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
            dropTargetBox.fillColor = NSColor(calibratedRed: 0.0, green: 0.4, blue: 0.8, alpha: 0.25)
            dropTargetBox.borderColor = NSColor(calibratedRed: 0.2, green: 0.85, blue: 0.95, alpha: 0.8)
        }
    }
    
    private func spawnNotes(at point: NSPoint, count: Int) {
        for _ in 0..<count {
            let emoji = Self.noteEmojis.randomElement() ?? "🎵"
            let offsetPoint = NSPoint(
                x: point.x + CGFloat.random(in: -25...25),
                y: point.y + CGFloat.random(in: -25...25)
            )
            let particle = EmojiParticleView(emoji: emoji, origin: offsetPoint)
            containerView.addSubview(particle, positioned: .above, relativeTo: appIconView)
            particles.append(particle)
        }
    }
    
    private func performInstallation() {
        // 1. Massive Musical Note Celebration Explosion!
        let targetCenter = NSPoint(
            x: dropTargetBox.frame.midX,
            y: dropTargetBox.frame.midY
        )
        spawnNotes(at: targetCenter, count: 50)
        
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

/// Transparent overlay view to capture drag events smoothly over the container.
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
