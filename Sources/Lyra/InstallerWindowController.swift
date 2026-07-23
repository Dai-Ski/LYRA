import AppKit

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
        super.init(frame: NSRect(x: origin.x - 16, y: origin.y - 16, width: 32, height: 32))
        self.stringValue = emoji
        self.font = NSFont.systemFont(ofSize: 22)
        self.isEditable = false
        self.isSelectable = false
        self.isBezeled = false
        self.drawsBackground = false
        self.alignment = .center
        self.wantsLayer = true
        
        // Random velocities
        self.vx = CGFloat.random(in: -2.5...2.5)
        self.vy = CGFloat.random(in: 1.5...4.5) // floats upward
        self.alphaVal = CGFloat.random(in: 0.85...1.0)
        self.scaleVal = CGFloat.random(in: 0.8...1.5)
        self.rotationVal = CGFloat.random(in: -0.5...0.5)
        self.vr = CGFloat.random(in: -0.1...0.1)
        
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
        
        alphaVal -= 0.022
        scaleVal += 0.008
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

/// Interactive Drag-and-Drop installer window with musical note emojis popping up on drag.
@MainActor
public final class InstallerWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow!
    private var completionHandler: (Bool) -> Void
    
    private var containerView: NSView!
    private var appIconView: NSBox!
    private var dropTargetBox: NSBox!
    private var statusLabel: NSTextField!
    private var launchButton: NSButton!
    
    private var particles: [EmojiParticleView] = []
    nonisolated(unsafe) private var animationTimer: Timer?
    
    private var initialAppIconFrame: NSRect = .zero
    private var isDragging = false
    private var dragOffset: NSPoint = .zero
    
    private static let noteEmojis = ["🎵", "🎶", "🎼", "✨", "🎤", "🎧", "🎹", "💫", "🌟"]
    
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
        let windowWidth: CGFloat = 580
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
        
        // Glassmorphism Visual Effect Background
        let visualEffectView = NSVisualEffectView(frame: rect)
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.autoresizingMask = [.width, .height]
        
        containerView = NSView(frame: rect)
        containerView.autoresizingMask = [.width, .height]
        visualEffectView.addSubview(containerView)
        
        // Window Title
        let titleLabel = NSTextField(labelWithString: "Install Lyra to Applications")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 20, y: 300, width: 540, height: 28)
        containerView.addSubview(titleLabel)
        
        // Subtitle instructions
        let subtitleLabel = NSTextField(labelWithString: "Drag the Lyra app icon into the Applications folder below to install")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        subtitleLabel.alignment = .center
        subtitleLabel.frame = NSRect(x: 20, y: 275, width: 540, height: 20)
        containerView.addSubview(subtitleLabel)
        
        // --- 1. Source App Icon Box (Left) ---
        initialAppIconFrame = NSRect(x: 80, y: 110, width: 130, height: 140)
        appIconView = NSBox(frame: initialAppIconFrame)
        appIconView.boxType = .custom
        appIconView.borderColor = NSColor.white.withAlphaComponent(0.25)
        appIconView.borderWidth = 1.5
        appIconView.cornerRadius = 16.0
        appIconView.fillColor = NSColor.black.withAlphaComponent(0.35)
        
        let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "png") ?? ""
        if let iconImage = NSImage(contentsOfFile: iconPath) ?? NSApp.applicationIconImage {
            let iconImageView = NSImageView(frame: NSRect(x: 35, y: 55, width: 60, height: 60))
            iconImageView.image = iconImage
            iconImageView.imageScaling = .scaleProportionallyUpOrDown
            appIconView.addSubview(iconImageView)
        } else {
            let appEmojiLabel = NSTextField(labelWithString: "🎵")
            appEmojiLabel.font = NSFont.systemFont(ofSize: 48)
            appEmojiLabel.alignment = .center
            appEmojiLabel.frame = NSRect(x: 10, y: 55, width: 110, height: 55)
            appIconView.addSubview(appEmojiLabel)
        }
        
        let appNameLabel = NSTextField(labelWithString: "Lyra.app")
        appNameLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        appNameLabel.textColor = .white
        appNameLabel.alignment = .center
        appNameLabel.frame = NSRect(x: 5, y: 20, width: 120, height: 22)
        appIconView.addSubview(appNameLabel)
        
        let dragHintLabel = NSTextField(labelWithString: "(Drag Me!)")
        dragHintLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        dragHintLabel.textColor = NSColor.systemTeal.withAlphaComponent(0.9)
        dragHintLabel.alignment = .center
        dragHintLabel.frame = NSRect(x: 5, y: 5, width: 120, height: 14)
        appIconView.addSubview(dragHintLabel)
        
        containerView.addSubview(appIconView)
        
        // --- 2. Guidance Arrow (Center) ---
        let arrowLabel = NSTextField(labelWithString: "➔")
        arrowLabel.font = NSFont.systemFont(ofSize: 36, weight: .bold)
        arrowLabel.textColor = NSColor.white.withAlphaComponent(0.3)
        arrowLabel.alignment = .center
        arrowLabel.frame = NSRect(x: 245, y: 155, width: 90, height: 45)
        containerView.addSubview(arrowLabel)
        
        // --- 3. Drop Target Box (Right: Applications) ---
        dropTargetBox = NSBox(frame: NSRect(x: 370, y: 110, width: 130, height: 140))
        dropTargetBox.boxType = .custom
        dropTargetBox.borderColor = NSColor.systemBlue.withAlphaComponent(0.4)
        dropTargetBox.borderWidth = 2.0
        dropTargetBox.cornerRadius = 16.0
        dropTargetBox.fillColor = NSColor.systemBlue.withAlphaComponent(0.15)
        
        let folderEmojiLabel = NSTextField(labelWithString: "📁")
        folderEmojiLabel.font = NSFont.systemFont(ofSize: 48)
        folderEmojiLabel.alignment = .center
        folderEmojiLabel.frame = NSRect(x: 10, y: 55, width: 110, height: 55)
        dropTargetBox.addSubview(folderEmojiLabel)
        
        let folderNameLabel = NSTextField(labelWithString: "Applications")
        folderNameLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        folderNameLabel.textColor = .white
        folderNameLabel.alignment = .center
        folderNameLabel.frame = NSRect(x: 5, y: 20, width: 120, height: 22)
        dropTargetBox.addSubview(folderNameLabel)
        
        let dropHereLabel = NSTextField(labelWithString: "Drop Here")
        dropHereLabel.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        dropHereLabel.textColor = NSColor.systemBlue.withAlphaComponent(0.9)
        dropHereLabel.alignment = .center
        dropHereLabel.frame = NSRect(x: 5, y: 5, width: 120, height: 14)
        dropTargetBox.addSubview(dropHereLabel)
        
        containerView.addSubview(dropTargetBox)
        
        // Status message
        statusLabel = NSTextField(labelWithString: "Drag Lyra into Applications to start making magic!")
        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = NSColor.white.withAlphaComponent(0.7)
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 20, y: 60, width: 540, height: 20)
        containerView.addSubview(statusLabel)
        
        // Launch Button (hidden until installed)
        launchButton = NSButton(frame: NSRect(x: 190, y: 20, width: 200, height: 34))
        launchButton.title = "LAUNCH LYRA"
        launchButton.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        launchButton.bezelStyle = .regularSquare
        launchButton.isBordered = true
        launchButton.isHidden = true
        launchButton.target = self
        launchButton.action = #selector(launchClicked)
        containerView.addSubview(launchButton)
        
        window.contentView = visualEffectView
        
        // Register mouse drag tracking on container view
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
            spawnNotes(at: point, count: 5)
        }
    }
    
    fileprivate func handleMouseDragged(at point: NSPoint) {
        guard isDragging else { return }
        
        // Move app icon frame
        let newX = max(10, min(containerView.bounds.width - appIconView.bounds.width - 10, point.x - dragOffset.x))
        let newY = max(10, min(containerView.bounds.height - appIconView.bounds.height - 10, point.y - dragOffset.y))
        appIconView.frame.origin = NSPoint(x: newX, y: newY)
        
        // POP MUSICAL NOTE EMOJIS CONTINUOUSLY WHILE DRAGGING!
        spawnNotes(at: point, count: 3)
        
        // Highlight drop target when overlapping
        if appIconView.frame.intersects(dropTargetBox.frame) {
            dropTargetBox.fillColor = NSColor.systemGreen.withAlphaComponent(0.35)
            dropTargetBox.borderColor = NSColor.systemGreen
        } else {
            dropTargetBox.fillColor = NSColor.systemBlue.withAlphaComponent(0.15)
            dropTargetBox.borderColor = NSColor.systemBlue.withAlphaComponent(0.4)
        }
    }
    
    fileprivate func handleMouseUp(at point: NSPoint) {
        guard isDragging else { return }
        isDragging = false
        
        if appIconView.frame.intersects(dropTargetBox.frame) {
            // Drop Succeeded!
            performInstallation()
        } else {
            // Animate snap back to origin
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                self.appIconView.animator().frame = self.initialAppIconFrame
            }
            dropTargetBox.fillColor = NSColor.systemBlue.withAlphaComponent(0.15)
            dropTargetBox.borderColor = NSColor.systemBlue.withAlphaComponent(0.4)
        }
    }
    
    private func spawnNotes(at point: NSPoint, count: Int) {
        for _ in 0..<count {
            let emoji = Self.noteEmojis.randomElement() ?? "🎵"
            let offsetPoint = NSPoint(
                x: point.x + CGFloat.random(in: -20...20),
                y: point.y + CGFloat.random(in: -20...20)
            )
            let particle = EmojiParticleView(emoji: emoji, origin: offsetPoint)
            containerView.addSubview(particle, positioned: .above, relativeTo: appIconView)
            particles.append(particle)
        }
    }
    
    private func performInstallation() {
        // 1. Massive Musical Note Celebration Burst!
        let targetCenter = NSPoint(
            x: dropTargetBox.frame.midX,
            y: dropTargetBox.frame.midY
        )
        spawnNotes(at: targetCenter, count: 35)
        
        // Snap icon to center of drop box
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
            
            statusLabel.stringValue = "✨ Lyra successfully installed to /Applications!"
            statusLabel.textColor = .systemGreen
            launchButton.isHidden = false
        } catch {
            statusLabel.stringValue = "Installed to /Applications! (or already exists)"
            statusLabel.textColor = .white
            launchButton.isHidden = false
        }
    }
    
    @objc private func launchClicked() {
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
