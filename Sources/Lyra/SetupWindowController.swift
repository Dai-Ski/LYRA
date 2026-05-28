import AppKit
import ServiceManagement

/// A custom, boxy setup onboarding interface using frosted glass visual effects.
@MainActor
final class SetupWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow!
    private let debugMode: Bool
    private let completionHandler: (Bool) -> Void
    private var isSetupCompleted = false
    
    init(debug: Bool, completion: @escaping (Bool) -> Void) {
        self.debugMode = debug
        self.completionHandler = completion
        super.init()
        setupWindow()
    }
    
    private func setupWindow() {
        // 1. Content size definition
        let rect = NSRect(x: 0, y: 0, width: 440, height: 260)
        
        // 2. Custom NSWindow creation
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
        
        // Center the window on the active display
        window.center()
        
        // 3. Frosted Glass visual effect view (Glassmorphism backdrop)
        let visualEffectView = NSVisualEffectView(frame: rect)
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.autoresizingMask = [.width, .height]
        
        // 4. Primary Container View
        let containerView = NSView(frame: rect)
        containerView.autoresizingMask = [.width, .height]
        
        // App Title Logo
        let logoLabel = NSTextField(labelWithString: "L Y R A")
        logoLabel.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        logoLabel.textColor = .white
        logoLabel.alignment = .center
        logoLabel.frame = NSRect(x: 20, y: 195, width: 400, height: 30)
        containerView.addSubview(logoLabel)
        
        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "Synchronized lyrics in your macOS menu bar")
        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.5)
        subtitleLabel.alignment = .center
        subtitleLabel.frame = NSRect(x: 20, y: 175, width: 400, height: 20)
        containerView.addSubview(subtitleLabel)
        
        // 5. Boxy Description Card
        let descriptionBox = NSBox(frame: NSRect(x: 30, y: 75, width: 380, height: 85))
        descriptionBox.boxType = .custom
        descriptionBox.borderColor = NSColor.white.withAlphaComponent(0.15)
        descriptionBox.borderWidth = 1.0
        descriptionBox.cornerRadius = 6.0
        descriptionBox.fillColor = NSColor.black.withAlphaComponent(0.2)
        
        let descText = "To function, Lyra needs permission to control Spotify & Apple Music, and will register to start automatically when you log in. It runs silently, appearing only when a music app is active.\n\nNote: Music apps will open briefly to trigger permissions."
        let descLabel = NSTextField(wrappingLabelWithString: descText)
        descLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        descLabel.textColor = NSColor.white.withAlphaComponent(0.8)
        descLabel.alignment = .center
        descLabel.frame = NSRect(x: 12, y: 8, width: 356, height: 70)
        descriptionBox.addSubview(descLabel)
        containerView.addSubview(descriptionBox)
        
        // 6. Action Buttons (Square Bezel / Boxy style)
        let grantButton = NSButton(frame: NSRect(x: 30, y: 25, width: 260, height: 32))
        grantButton.title = "GRANT PERMISSIONS & START"
        grantButton.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        grantButton.bezelStyle = .regularSquare
        grantButton.isBordered = true
        grantButton.target = self
        grantButton.action = #selector(grantClicked)
        containerView.addSubview(grantButton)
        
        let quitButton = NSButton(frame: NSRect(x: 300, y: 25, width: 110, height: 32))
        quitButton.title = "QUIT"
        quitButton.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        quitButton.bezelStyle = .regularSquare
        quitButton.isBordered = true
        quitButton.target = self
        quitButton.action = #selector(quitClicked)
        containerView.addSubview(quitButton)
        
        // Assemble View Hierarchy
        visualEffectView.addSubview(containerView)
        window.contentView = visualEffectView
    }
    
    /// Displays the setup window and makes it key.
    public func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    
    @objc private func grantClicked() {
        requestAutomationPermissions()
        registerLoginItem()
        
        let successAlert = NSAlert()
        successAlert.messageText = "Setup Complete"
        successAlert.informativeText = "Permissions requested and auto-launch enabled! Lyra will now run in the background. It will automatically appear in your menu bar when Spotify or Apple Music is active, and disappear when they are closed."
        successAlert.addButton(withTitle: "Start Lyra")
        successAlert.window.level = .floating
        successAlert.window.orderFrontRegardless()
        successAlert.runModal()
        
        isSetupCompleted = true
        window.close()
        NSApp.setActivationPolicy(.accessory)
        completionHandler(true)
    }
    
    @objc private func quitClicked() {
        window.close()
        completionHandler(false)
    }
    
    func windowWillClose(_ notification: Notification) {
        if !isSetupCompleted {
            completionHandler(false)
        }
    }
    
    private func requestAutomationPermissions() {
        let spotifyScript = NSAppleScript(source: "tell application \"Spotify\" to get player state")
        var errorInfo: NSDictionary? = nil
        _ = spotifyScript?.executeAndReturnError(&errorInfo)
        
        let musicScript = NSAppleScript(source: "tell application \"Music\" to get player state")
        errorInfo = nil
        _ = musicScript?.executeAndReturnError(&errorInfo)
    }
    
    private func registerLoginItem() {
        guard Bundle.main.bundleIdentifier == "com.daiski.lyra" else {
            if debugMode { print("[DEBUG] Not running from the packaged app bundle, skipping login item registration.") }
            return
        }
        let appService = SMAppService.mainApp
        do {
            if appService.status == .notRegistered {
                try appService.register()
            }
        } catch {
            if debugMode { print("[DEBUG] Failed to register login item: \(error.localizedDescription)") }
        }
    }
}