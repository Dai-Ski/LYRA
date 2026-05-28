import AppKit
import ServiceManagement

// 1. CLI Metadata & Help Manual
let VERSION = "1.0.0"
let GITHUB_REPO = "Dai-Ski/LYRA"
let HELP_MESSAGE = """
Lyra - Real-time Spotify & Apple Music Lyrics Menu Bar App for macOS
Version: \(VERSION)

Usage: lyra [options]

Options:
  -d, --debug             Print raw API responses and internal state changes
  --interval <seconds>    Override player polling interval (default: 2.0s)
  -v, --version           Print version information
  -h, --help              Print usage information
"""

// 2. Command Line Arguments Parsing
struct CLIArguments {
    var debug: Bool = false
    var interval: Double = 2.0
    var showHelp: Bool = false
    var showVersion: Bool = false
    
    static func parse() -> CLIArguments {
        var args = CLIArguments()
        var iterator = CommandLine.arguments.dropFirst().makeIterator()
        while let arg = iterator.next() {
            switch arg {
            case "--debug", "-d":
                args.debug = true
            case "--version", "-v":
                args.showVersion = true
            case "--help", "-h":
                args.showHelp = true
            case "--interval":
                if let next = iterator.next(), let sec = Double(next) {
                    args.interval = sec
                } else {
                    print("Error: --interval requires a numeric value.")
                    exit(1)
                }
            default:
                print("Unknown option: \(arg)")
                print(HELP_MESSAGE)
                exit(1)
            }
        }
        return args
    }
}

// 3. NSApplicationDelegate to manage application state and structured concurrency loops
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var stateActor: AppStateActor!
    private var client: LyricsClient!
    private var menuEngine: MenuBarEngine!
    private let pollingInterval: Double
    private let debugMode: Bool
    private var pollingTask: Task<Void, Never>?
    private var setupWindowController: SetupWindowController?
    
    init(interval: Double, debug: Bool) {
        self.pollingInterval = interval
        self.debugMode = debug
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        stateActor = AppStateActor()
        client = LyricsClient()
        menuEngine = MenuBarEngine()
        
        menuEngine.modeChangeHandler = { [weak self] mode in
            guard let self = self else { return }
            Task {
                await self.stateActor.setLyricMode(mode)
            }
        }
        
        // 1. Run onboarding setup flow if needed (first launch permissions)
        runSetupFlowIfNeeded()
        
        // 2. Set up workspace observers to monitor music app launch and termination
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppChange(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppChange(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        
        // 3. Determine initial visibility and start polling if any music app is already active
        updateAppVisibilityAndPolling()
        
        // Menu update loop task
        Task {
            await startUpdateLoop()
        }
        
        // Check for updates asynchronously on launch
        Task {
            let checker = UpdateChecker(currentVersion: VERSION, repo: GITHUB_REPO)
            if let update = await checker.checkForUpdates() {
                menuEngine.showUpdateAvailable(version: update.version, url: update.url)
            }
        }
    }
    
    @objc private func handleAppChange(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        if let bundleID = app.bundleIdentifier,
           bundleID == "com.spotify.client" || bundleID == "com.apple.Music" {
            updateAppVisibilityAndPolling()
        }
    }
    
    private func updateAppVisibilityAndPolling() {
        guard UserDefaults.standard.bool(forKey: "SetupCompleted") else {
            menuEngine.setVisible(false)
            return
        }
        
        let (spotifyRunning, musicRunning) = checkRunningApps()
        let isAnyRunning = spotifyRunning || musicRunning
        
        menuEngine.setVisible(isAnyRunning)
        
        if isAnyRunning {
            startPollingIfNeeded()
        } else {
            stopPolling()
        }
    }
    
    private func startPollingIfNeeded() {
        guard pollingTask == nil else { return }
        pollingTask = Task {
            await startMusicPollingLoop()
        }
    }
    
    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    private func runSetupFlowIfNeeded() {
        let userDefaults = UserDefaults.standard
        if userDefaults.bool(forKey: "SetupCompleted") {
            return
        }
        
        setupWindowController = SetupWindowController(debug: debugMode) { [weak self] success in
            guard let self = self else { return }
            if success {
                userDefaults.set(true, forKey: "SetupCompleted")
                self.updateAppVisibilityAndPolling()
            } else {
                NSApplication.shared.terminate(nil)
            }
        }
        setupWindowController?.show()
    }
    
    private func checkRunningApps() -> (spotify: Bool, music: Bool) {
        let runningApps = NSWorkspace.shared.runningApplications
        var spotifyRunning = false
        var musicRunning = false
        for app in runningApps {
            if app.bundleIdentifier == "com.spotify.client" {
                spotifyRunning = true
            } else if app.bundleIdentifier == "com.apple.Music" {
                musicRunning = true
            }
        }
        return (spotifyRunning, musicRunning)
    }
    
}