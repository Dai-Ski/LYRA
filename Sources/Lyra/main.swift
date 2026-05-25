import AppKit

// 1. CLI Metadata & Help Manual
let VERSION = "1.0.0"
let GITHUB_REPO = "Dai-Ski/LYRA"
let HELP_MESSAGE = """
Lyra - Real-time Spotify Lyrics Menu Bar App for macOS
Version: \(VERSION)

Usage: lyra [options]

Options:
  -d, --debug             Print raw API responses and internal state changes
  --interval <seconds>    Override Spotify polling interval (default: 2.0s)
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
    
    init(interval: Double, debug: Bool) {
        self.pollingInterval = interval
        self.debugMode = debug
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        stateActor = AppStateActor()
        client = LyricsClient()
        menuEngine = MenuBarEngine()
        
        // Polling loop task
        Task {
            await startSpotifyPollingLoop()
        }
        
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
    
    private func startSpotifyPollingLoop() async {
        let bridge = SpotifyBridge()
        var currentTrackKey = ""
        
        while true {
            do {
                let state = try await bridge.fetchCurrentState()
                
                switch state {
                case .notRunning:
                    await stateActor.updatePlayback(
                        isSpotifyRunning: false,
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
                        isSpotifyRunning: true,
                        isPlaying: false,
                        title: "",
                        artist: "",
                        album: "",
                        position: 0.0,
                        duration: 0.0
                    )
                    currentTrackKey = ""
                    
                case .paused(let track, let position), .playing(let track, let position):
                    var isPlaying = false
                    if case .playing = state {
                        isPlaying = true
                    }
                    
                    await stateActor.updatePlayback(
                        isSpotifyRunning: true,
                        isPlaying: isPlaying,
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
                                let lyrics = try await client.fetchLyrics(
                                    track: trackTitle,
                                    artist: trackArtist,
                                    album: trackAlbum,
                                    duration: trackDuration,
                                    debug: debugMode
                                )
                                await stateActor.setLyricsLoaded(lyrics, forKey: newTrackKey)
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
                await stateActor.updatePlayback(
                    isSpotifyRunning: true,
                    isPlaying: false,
                    title: "",
                    artist: "",
                    album: "",
                    position: 0.0,
                    duration: 0.0
                )
                await stateActor.setLyricsError(error.localizedDescription, forKey: "")
            }
            
            do {
                try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
            } catch {
                break
            }
        }
    }
    
    private func startUpdateLoop() async {
        while true {
            let playbackState = await stateActor.getState()
            let (lyrics, status) = await stateActor.getLyrics()
            
            menuEngine.update(state: playbackState, lyrics: lyrics, status: status)
            
            do {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms update rate
            } catch {
                break
            }
        }
    }
}

// 4. Execution Core
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
