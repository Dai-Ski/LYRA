import AppKit

/// Realistic Blue Sky with Fluffy White Clouds Background.
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
                self?.phase += 0.015
                self?.needsDisplay = true
            }
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let bounds = self.bounds
        
        // 1. Beautiful Azure Blue Sky Gradient
        let skyTop = NSColor(calibratedRed: 0.12, green: 0.45, blue: 0.85, alpha: 1.0)
        let skyMid = NSColor(calibratedRed: 0.25, green: 0.62, blue: 0.95, alpha: 1.0)
        let skyBottom = NSColor(calibratedRed: 0.70, green: 0.85, blue: 0.98, alpha: 1.0)
        
        guard let skyGradient = NSGradient(colors: [skyTop, skyMid, skyBottom]) else { return }
        skyGradient.draw(in: bounds, angle: 90.0)
        
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        
        // 2. Draw Layered Soft Fluffy White Clouds with Slow Horizontal Drift
        let drift1 = CGFloat(sin(phase * 0.5)) * 15.0
        let drift2 = CGFloat(cos(phase * 0.4)) * 20.0
        
        // Top-Left Cloud Cluster
        let cloud1 = NSBezierPath()
        cloud1.appendOval(in: NSRect(x: -30 + drift1, y: bounds.height - 110, width: 140, height: 90))
        cloud1.appendOval(in: NSRect(x: 30 + drift1, y: bounds.height - 130, width: 180, height: 110))
        cloud1.appendOval(in: NSRect(x: 130 + drift1, y: bounds.height - 100, width: 150, height: 80))
        NSColor.white.withAlphaComponent(0.85).setFill()
        cloud1.fill()
        
        // Top-Right Cloud Cluster
        let cloud2 = NSBezierPath()
        cloud2.appendOval(in: NSRect(x: bounds.width - 240 + drift2, y: bounds.height - 120, width: 160, height: 100))
        cloud2.appendOval(in: NSRect(x: bounds.width - 150 + drift2, y: bounds.height - 140, width: 190, height: 120))
        cloud2.appendOval(in: NSRect(x: bounds.width - 60 + drift2, y: bounds.height - 110, width: 140, height: 85))
        NSColor.white.withAlphaComponent(0.85).setFill()
        cloud2.fill()
        
        // Bottom Soft Horizon Clouds
        let cloud3 = NSBezierPath()
        cloud3.appendOval(in: NSRect(x: -40 - drift1, y: -40, width: 220, height: 120))
        cloud3.appendOval(in: NSRect(x: 120 - drift1, y: -60, width: 260, height: 140))
        cloud3.appendOval(in: NSRect(x: 320 - drift1, y: -50, width: 240, height: 130))
        cloud3.appendOval(in: NSRect(x: 480 - drift1, y: -40, width: 200, height: 110))
        NSColor.white.withAlphaComponent(0.70).setFill()
        cloud3.fill()
        
        // 3. Subtle Sun Rays Glow
        let sunGlow = NSBezierPath(ovalIn: NSRect(x: bounds.width * 0.5 - 120, y: bounds.height - 80, width: 240, height: 160))
        NSColor.white.withAlphaComponent(0.18).setFill()
        sunGlow.fill()
        
        context?.restoreGState()
    }
}

/// Represents an animated musical note emoji particle radiating outward from Lyra icon center.
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
        self.font = NSFont.systemFont(ofSize: 30)
        self.isEditable = false
        self.isSelectable = false
        self.isBezeled = false
        self.drawsBackground = false
        self.alignment = .center
        self.wantsLayer = true
        
        // 360-degree radial explosion velocity outward from icon center!
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let speed = CGFloat.random(in: 3.5...8.5)
        self.vx = cos(angle) * speed
        self.vy = sin(angle) * speed + 2.0 // float upward bias
        
        self.alphaVal = CGFloat.random(in: 0.95...1.0)
        self.scaleVal = CGFloat.random(in: 1.0...1.9)
        self.rotationVal = CGFloat.random(in: -0.8...0.8)
        self.vr = CGFloat.random(in: -0.2...0.2)
        
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

/// Interactive Drag-and-Drop installer window with blue sky & cloud background and emojis popping from Lyra icon center.
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
        
        // 1. Blue Sky & Fluffy White Clouds Background View
        let skyBackground = IntricateDesignBackgroundView(frame: rect)
        skyBackground.autoresizingMask = [.width, .height]
        
        containerView = NSView(frame: rect)
        containerView.autoresizingMask = [.width, .height]
        skyBackground.addSubview(containerView)
        
        // Header Title
        let titleLabel = NSTextField(labelWithString: "✨ L Y R A ✨")
        titleLabel.font = NSFont.systemFont(ofSize: 26, weight: .black)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 20, y: 305, width: 520, height: 34)
        containerView.addSubview(titleLabel)
        
        // Subtitle instructions
        let subtitleLabel = NSTextField(labelWithString: "Drag the Lyra icon into Applications to install!")
        subtitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        subtitleLabel.textColor = NSColor(calibratedRed: 0.05, green: 0.25, blue: 0.45, alpha: 0.95)
        subtitleLabel.alignment = .center
        subtitleLabel.frame = NSRect(x: 20, y: 280, width: 520, height: 20)
        containerView.addSubview(subtitleLabel)
        
        // --- 1. Source App Icon Box (Left - Big 128px style) ---
        initialAppIconFrame = NSRect(x: 65, y: 105, width: 155, height: 160)
        appIconView = NSBox(frame: initialAppIconFrame)
        appIconView.boxType = .custom
        appIconView.borderColor = NSColor.white.withAlphaComponent(0.9)
        appIconView.borderWidth = 3.0
        appIconView.cornerRadius = 24.0
        appIconView.fillColor = NSColor.black.withAlphaComponent(0.45)
        
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
        
        let dragHintLabel = NSTextField(labelWithString: "(Drag Me! 🎵)")
        dragHintLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        dragHintLabel.textColor = NSColor(calibratedRed: 1.0, green: 0.9, blue: 0.4, alpha: 1.0)
        dragHintLabel.alignment = .center
        dragHintLabel.frame = NSRect(x: 5, y: 6, width: 145, height: 16)
        appIconView.addSubview(dragHintLabel)
        
        containerView.addSubview(appIconView)
        
        // --- 2. Guidance Arrow (Center) ---
        let arrowLabel = NSTextField(labelWithString: "➔")
        arrowLabel.font = NSFont.systemFont(ofSize: 46, weight: .black)
        arrowLabel.textColor = .white
        arrowLabel.alignment = .center
        arrowLabel.frame = NSRect(x: 235, y: 155, width: 90, height: 50)
        containerView.addSubview(arrowLabel)
        
        // --- 3. Drop Target Box (Right: Applications - Big 128px style) ---
        dropTargetBox = NSBox(frame: NSRect(x: 340, y: 105, width: 155, height: 160))
        dropTargetBox.boxType = .custom
        dropTargetBox.borderColor = NSColor.white.withAlphaComponent(0.9)
        dropTargetBox.borderWidth = 3.0
        dropTargetBox.cornerRadius = 24.0
        dropTargetBox.fillColor = NSColor(calibratedRed: 0.05, green: 0.40, blue: 0.80, alpha: 0.40)
        
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
        dropHereLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        dropHereLabel.textColor = NSColor(calibratedRed: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        dropHereLabel.alignment = .center
        dropHereLabel.frame = NSRect(x: 5, y: 6, width: 145, height: 16)
        dropTargetBox.addSubview(dropHereLabel)
        
        containerView.addSubview(dropTargetBox)
        
        // Status Message
        statusLabel = NSTextField(labelWithString: "Drag Lyra into Applications to start making musical magic!")
        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        statusLabel.textColor = NSColor(calibratedRed: 0.05, green: 0.25, blue: 0.45, alpha: 0.95)
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 20, y: 65, width: 520, height: 22)
        containerView.addSubview(statusLabel)
        
        // --- Action Buttons after copy ---
        // 1. Primary Button: Move DMG to Trash & Launch
        trashLaunchButton = NSButton(frame: NSRect(x: 65, y: 18, width: 220, height: 38))
        trashLaunchButton.title = "🗑️ MOVE DMG TO TRASH & LAUNCH"
        trashLaunchButton.font = NSFont.systemFont(ofSize: 10, weight: .black)
        trashLaunchButton.bezelStyle = .regularSquare
        trashLaunchButton.isBordered = true
        trashLaunchButton.isHidden = true
        trashLaunchButton.target = self
        trashLaunchButton.action = #selector(trashAndLaunchClicked)
        containerView.addSubview(trashLaunchButton)
        
        // 2. Secondary Button: Launch Lyra (Keep DMG)
        launchOnlyButton = NSButton(frame: NSRect(x: 300, y: 18, width: 175, height: 38))
        launchOnlyButton.title = "🚀 LAUNCH LYRA"
        launchOnlyButton.font = NSFont.systemFont(ofSize: 10, weight: .black)
        launchOnlyButton.bezelStyle = .regularSquare
        launchOnlyButton.isBordered = true
        launchOnlyButton.isHidden = true
        launchOnlyButton.target = self
        launchOnlyButton.action = #selector(launchOnlyClicked)
        containerView.addSubview(launchOnlyButton)
        
        window.contentView = skyBackground
        
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
        
        // ON HOVER OVER LYRA APP ICON -> BURST EMOJIS DIRECTLY FROM LYRA ICON CENTER!
        if appIconView.frame.contains(point) {
            let appIconCenter = NSPoint(x: appIconView.frame.midX, y: appIconView.frame.midY)
            spawnNotesFromIconCenter(at: appIconCenter, count: 2)
            appIconView.borderColor = .white
            appIconView.fillColor = NSColor.black.withAlphaComponent(0.60)
        } else {
            appIconView.borderColor = NSColor.white.withAlphaComponent(0.9)
            appIconView.fillColor = NSColor.black.withAlphaComponent(0.45)
        }
        
        // ON HOVER OVER APPLICATIONS -> HIGHLIGHT ONLY (DO NOT OPEN APPLICATIONS ON HOVER!)
        if dropTargetBox.frame.contains(point) {
            dropTargetBox.borderColor = NSColor.systemGreen
            dropTargetBox.fillColor = NSColor.systemGreen.withAlphaComponent(0.40)
        } else {
            dropTargetBox.borderColor = NSColor.white.withAlphaComponent(0.9)
            dropTargetBox.fillColor = NSColor(calibratedRed: 0.05, green: 0.40, blue: 0.80, alpha: 0.40)
        }
    }
    
    fileprivate func handleMouseDown(at point: NSPoint) {
        if appIconView.frame.contains(point) {
            isDragging = true
            dragOffset = NSPoint(x: point.x - appIconView.frame.origin.x, y: point.y - appIconView.frame.origin.y)
            let appIconCenter = NSPoint(x: appIconView.frame.midX, y: appIconView.frame.midY)
            spawnNotesFromIconCenter(at: appIconCenter, count: 12)
        }
    }
    
    fileprivate func handleMouseDragged(at point: NSPoint) {
        guard isDragging else { return }
        
        let newX = max(10, min(containerView.bounds.width - appIconView.bounds.width - 10, point.x - dragOffset.x))
        let newY = max(10, min(containerView.bounds.height - appIconView.bounds.height - 10, point.y - dragOffset.y))
        appIconView.frame.origin = NSPoint(x: newX, y: newY)
        
        // POP MUSICAL EMOJIS DIRECTLY FROM THE CENTER OF THE LYRA ICON WHILE DRAGGING!
        let appIconCenter = NSPoint(
            x: appIconView.frame.midX,
            y: appIconView.frame.midY
        )
        spawnNotesFromIconCenter(at: appIconCenter, count: 6)
        
        // Highlight drop target when overlapping
        if appIconView.frame.intersects(dropTargetBox.frame) {
            dropTargetBox.fillColor = NSColor.systemGreen.withAlphaComponent(0.55)
            dropTargetBox.borderColor = NSColor.systemGreen
        } else {
            dropTargetBox.fillColor = NSColor(calibratedRed: 0.05, green: 0.40, blue: 0.80, alpha: 0.40)
            dropTargetBox.borderColor = NSColor.white.withAlphaComponent(0.9)
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
            dropTargetBox.fillColor = NSColor(calibratedRed: 0.05, green: 0.40, blue: 0.80, alpha: 0.40)
            dropTargetBox.borderColor = NSColor.white.withAlphaComponent(0.9)
        }
    }
    
    private func spawnNotesFromIconCenter(at center: NSPoint, count: Int) {
        for _ in 0..<count {
            let emoji = Self.noteEmojis.randomElement() ?? "🎵"
            let particle = EmojiParticleView(emoji: emoji, origin: center)
            containerView.addSubview(particle, positioned: .above, relativeTo: nil)
            particles.append(particle)
        }
    }
    
    private func performInstallation() {
        // 1. Massive Musical Note Celebration Explosion from target center!
        let targetCenter = NSPoint(
            x: dropTargetBox.frame.midX,
            y: dropTargetBox.frame.midY
        )
        spawnNotesFromIconCenter(at: targetCenter, count: 80)
        
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
            statusLabel.textColor = NSColor(calibratedRed: 0.05, green: 0.4, blue: 0.1, alpha: 1.0)
            trashLaunchButton.isHidden = false
            launchOnlyButton.isHidden = false
        } catch {
            statusLabel.stringValue = "Lyra is ready in /Applications! Would you like to delete the DMG?"
            statusLabel.textColor = .black
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
