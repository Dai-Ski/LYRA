import Foundation

/// A component that queries Spotify on macOS using AppleScript.
public struct SpotifyBridge: Sendable {

    // AppleScript command to fetch playback states and song metadata.
    // Uses ASCII unit separator (0x1F) as delimiter to avoid conflicts with song/artist names.
    private static let getPlaybackStateScript = """
    tell application "Spotify"
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
            set trackId to ""

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
                set trackId to id of current track
            end try

            return trackName & sep & trackArtist & sep & trackAlbum & sep & (trackDuration as string) & sep & (trackPosition as string) & sep & playerState & sep & trackId
        end if
    end tell
    """

    /// Error types specific to the Spotify AppleScript Bridge.
    public enum SpotifyBridgeError: LocalizedError {
        case spotifyNotRunning
        case appleScriptError(code: Int, message: String)
        case permissionDenied
        case invalidResponse

        public var errorDescription: String? {
            switch self {
            case .spotifyNotRunning:
                return "Spotify is not running."
            case .appleScriptError(let code, let msg):
                return "AppleScript execution failed with code \(code): \(msg)"
            case .permissionDenied:
                return "Automation permission denied. Please grant Lyra control permission in 'System Settings > Privacy & Security > Automation'."
            case .invalidResponse:
                return "Failed to parse metadata returned by Spotify AppleScript."
            }
        }
    }

    public init() {}

    /// Fetches the current playback status of Spotify.
    /// - Parameter isRunning: Boolean representing if Spotify is currently running.
    /// - Returns: A strongly typed `MusicPlayerState` representing the player.
    public func fetchCurrentState(isRunning: Bool) async throws -> MusicPlayerState {
        guard isRunning else { return .notRunning }

        let stateStr: String
        do {
            stateStr = try await executeAppleScript(Self.getPlaybackStateScript)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            // Script failed — check if an ad is playing
            let pState = (try? await executeAppleScript(
                "tell application \"Spotify\" to player state as string"
            ).trimmingCharacters(in: .whitespacesAndNewlines)) ?? "stopped"
            if pState == "playing" {
                return .playing(track: MusicTrack(title: "Advertisement??", artist: "", album: "", duration: 0.0), position: 0.0)
            }
            return .stopped
        }

        if stateStr == "stopped" { return .stopped }

        // Split on ASCII unit separator (0x1F) — safe against special chars in metadata
        let sep = "\u{1F}"
        let parts = stateStr.components(separatedBy: sep)

        guard parts.count == 7 else {
            let pState = (try? await executeAppleScript(
                "tell application \"Spotify\" to player state as string"
            ).trimmingCharacters(in: .whitespacesAndNewlines)) ?? "stopped"
            if pState == "playing" {
                return .playing(track: MusicTrack(title: "Advertisement??", artist: "", album: "", duration: 0.0), position: 0.0)
            }
            return .stopped
        }

        let title       = parts[0].trimmingCharacters(in: .whitespaces)
        let artist      = parts[1].trimmingCharacters(in: .whitespaces)
        let album       = parts[2].trimmingCharacters(in: .whitespaces)
        let playerState = parts[5].trimmingCharacters(in: .whitespaces)
        let trackId     = parts[6].trimmingCharacters(in: .whitespaces)

        // Spotify returns duration in milliseconds → convert to seconds
        let durationMs  = Double(parts[3]) ?? 0.0
        let positionSec = Double(parts[4]) ?? 0.0
        let durationSec = durationMs / 1000.0

        // Detect advertisements:
        // - trackId starts with "spotify:ad" or contains ":ad:"
        // - title is empty
        // - trackId is empty
        // - trackId doesn't match known prefixes (track, local file, podcast episode)
        let isAd = trackId.hasPrefix("spotify:ad")
                || trackId.contains(":ad:")
                || title.isEmpty
                || trackId.isEmpty
                || (!trackId.hasPrefix("spotify:track")
                    && !trackId.hasPrefix("spotify:local")
                    && !trackId.hasPrefix("spotify:episode"))

        let finalTitle  = isAd ? "Advertisement??" : title
        let finalArtist = isAd ? "" : artist
        let finalAlbum  = isAd ? "" : album

        let track = MusicTrack(
            title: finalTitle,
            artist: finalArtist,
}