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
    private var installerWindowController: InstallerWindowController?
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
        
        // 1. Check if running outside /Applications directory -> launch Drag & Drop installer
        let isInsideApplications = Bundle.main.bundlePath.hasPrefix("/Applications")
        if !isInsideApplications && !debugMode {
            installerWindowController = InstallerWindowController { _ in
                NSApplication.shared.terminate(nil)
            }
            installerWindowController?.show()
            return
        }
        
        // 2. Run onboarding setup flow if needed (first launch permissions)
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
    
    private func startMusicPollingLoop() async {
        let spotifyBridge = SpotifyBridge()
        let musicBridge = AppleMusicBridge()
        var currentTrackKey = ""
        
        while !Task.isCancelled {
            var isPlayingNow = false
            do {
                let (spotifyRunning, musicRunning) = checkRunningApps()
                
                var activeState: MusicPlayerState = .notRunning
                
                if spotifyRunning && musicRunning {
                    let spotifyState = try await spotifyBridge.fetchCurrentState(isRunning: spotifyRunning)
                    let musicState = try await musicBridge.fetchCurrentState(isRunning: musicRunning)
                    
                    switch (spotifyState, musicState) {
                    case (.playing, _):
                        activeState = spotifyState
                    case (_, .playing):
                        activeState = musicState
                    case (.paused, _):
                        activeState = spotifyState
                    case (_, .paused):
                        activeState = musicState
                    default:
                        activeState = spotifyState
                    }
                } else if spotifyRunning {
                    activeState = try await spotifyBridge.fetchCurrentState(isRunning: spotifyRunning)
                } else if musicRunning {
                    activeState = try await musicBridge.fetchCurrentState(isRunning: musicRunning)
                } else {
                    activeState = .notRunning
                }
                
                if debugMode {
                    print("[DEBUG] Running apps - Spotify: \(spotifyRunning), Music: \(musicRunning)")
                    switch activeState {
                    case .notRunning:
                        print("[DEBUG] Active State: notRunning")
                    case .stopped:
                        print("[DEBUG] Active State: stopped")
                    case .paused(let track, let pos):
                        print("[DEBUG] Active State: paused (\(track.artist) - \(track.title)) at position \(pos)")
                    case .playing(let track, let pos):
                        print("[DEBUG] Active State: playing (\(track.artist) - \(track.title)) at position \(pos)")
                    }
                }
                
                switch activeState {
                case .notRunning:
                    await stateActor.updatePlayback(
                        isMusicRunning: false,
                        isPlaying: false,
                        title: "",
                        artist: "",
                        album: "",
                        position: 0.0,
                        duration: 0.0
                    )
                    currentTrackKey = ""
                    
                case .stopped:
                    await stateActor.updatePlayback(
                        isMusicRunning: true,
                        isPlaying: false,
                        title: "",
                        artist: "",
                        album: "",
                        position: 0.0,
                        duration: 0.0
                    )
                    currentTrackKey = ""
                    
                case .paused(let track, let position), .playing(let track, let position):
                    if case .playing = activeState {
                        isPlayingNow = true
                    }
                    
                    await stateActor.updatePlayback(
                        isMusicRunning: true,
                        isPlaying: isPlayingNow,
                        title: track.title,
                        artist: track.artist,
                        album: track.album,
                        position: position,
                        duration: track.duration
                    )
                    
                    let newTrackKey = track.trackKey
                    if newTrackKey != currentTrackKey && !newTrackKey.isEmpty {
                        currentTrackKey = newTrackKey
                        
                        await stateActor.setLyricsLoading()
                        
                        let trackTitle = track.title
                        let trackArtist = track.artist
                        let trackAlbum = track.album
                        let trackDuration = track.duration
                        
                        Task {
                            if trackTitle == "Advertisement??" {
                                await stateActor.setLyricsNotFound(forKey: newTrackKey)
                                return
                            }
                            do {
                                let lyricSet = try await client.fetchLyrics(
                                    track: trackTitle,
                                    artist: trackArtist,
                                    album: trackAlbum,
                                    duration: trackDuration,
                                    debug: debugMode
                                )
                                await stateActor.setLyricsLoaded(
                                    original: lyricSet.original,
                                    romanized: lyricSet.romanized,
                                    forKey: newTrackKey
                                )
                            } catch let err as LyricsError {
                                if case .notFound = err {
                                    await stateActor.setLyricsNotFound(forKey: newTrackKey)
                                } else {
                                    await stateActor.setLyricsError(err.localizedDescription, forKey: newTrackKey)
                                }
                            } catch {
                                await stateActor.setLyricsError(error.localizedDescription, forKey: newTrackKey)
                            }
                        }
                    }
                }
            } catch {
                if debugMode { print("[DEBUG] Error in polling loop: \(error.localizedDescription)") }
                await stateActor.updatePlayback(
                    isMusicRunning: true,
                    isPlaying: false,
                    title: "",
                    artist: "",
                    album: "",
                    position: 0.0,
                    duration: 0.0
                )
                await stateActor.setLyricsError(error.localizedDescription, forKey: "")
            }
            
            let sleepSec = isPlayingNow ? min(1.0, pollingInterval) : pollingInterval
            do {
                try await Task.sleep(nanoseconds: UInt64(sleepSec * 1_000_000_000))
            } catch {
                break
            }
        }
    }
    
    private func startUpdateLoop() async {
        while true {
            let playbackState = await stateActor.getState()
            let (lyrics, status, mode, availableModes) = await stateActor.getLyrics()
            
            menuEngine.update(
                state: playbackState,
                lyrics: lyrics,
                status: status,
                mode: mode,
                availableModes: availableModes
            )
            
            do {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms update rate
            } catch {
                break
            }
        }
    }
}

// 4. Execution Core
setvbuf(stdout, nil, _IONBF, 0)
let args = CLIArguments.parse()

if args.showHelp {
    print(HELP_MESSAGE)
    exit(0)
}
if args.showVersion {
    print("Lyra version \(VERSION)")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate(interval: args.interval, debug: args.debug)
app.delegate = delegate

// Configure the app to run as a background accessory (no Dock icon, no window activation)
app.setActivationPolicy(.accessory)

app.run()