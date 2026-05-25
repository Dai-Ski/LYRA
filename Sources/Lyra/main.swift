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
    }
}

extension AppDelegate {
    private func startSpotifyPollingLoop() async {
        let bridge = SpotifyBridge()
        var currentTrackKey = ""
        
        while true {
            do {
                let state = try await bridge.fetchCurrentState()
                // Staged loop logic...
            } catch {
                // Handle errors...
            }
            try? await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
        }
    }
}
