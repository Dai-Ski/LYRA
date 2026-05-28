import Foundation

/// A component that queries Apple Music (Music app) on macOS using AppleScript.
public struct AppleMusicBridge: Sendable {

    // AppleScript command to fetch playback states and song metadata.
    // Uses ASCII unit separator (0x1F) as delimiter to avoid conflicts with song/artist names.
    private static let getPlaybackStateScript = """
    tell application "Music"
        if player state is stopped then
            return "stopped"
        else
            set sep to ASCII character 31
            set trackName to ""
            set trackArtist to ""
            set trackAlbum to ""
            set trackDuration to 0
            set trackPosition to 0
            set playerState to "stopped"
            set trackKind to ""

            try
                set trackName to name of current track
            end try
            try
                set trackArtist to artist of current track
            end try
            try
                set trackAlbum to album of current track
            end try
            try
                set trackDuration to duration of current track
            end try
            try
                set trackPosition to player position
            end try
            try
                set playerState to player state as string
            end try
            try
                set trackKind to kind of current track as string
            end try

            return trackName & sep & trackArtist & sep & trackAlbum & sep & (trackDuration as string) & sep & (trackPosition as string) & sep & playerState & sep & trackKind
        end if
    end tell
    """

    /// Error types specific to the Apple Music AppleScript Bridge.
    public enum AppleMusicBridgeError: LocalizedError {
        case musicNotRunning
        case appleScriptError(code: Int, message: String)
        case permissionDenied
        case invalidResponse

        public var errorDescription: String? {
            switch self {
            case .musicNotRunning:
                return "Apple Music is not running."
            case .appleScriptError(let code, let msg):
                return "AppleScript execution failed with code \(code): \(msg)"
            case .permissionDenied:
                return "Automation permission denied. Please grant Lyra control permission in 'System Settings > Privacy & Security > Automation'."
            case .invalidResponse:
                return "Failed to parse metadata returned by Apple Music AppleScript."
            }
        }
    }

    public init() {}
}