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
    
}