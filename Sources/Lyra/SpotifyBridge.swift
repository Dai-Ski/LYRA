import Foundation

/// A component that queries Spotify on macOS using AppleScript.
public struct SpotifyBridge: Sendable {
    
    // AppleScript command to verify if Spotify is running without launching it.
    private static let isRunningScript = """
    tell application "System Events"
        return exists (processes where name is "Spotify")
    end tell
    """

    // AppleScript command to fetch playback states and song metadata.
    private static let getPlaybackStateScript = """
    tell application "Spotify"
        if player state is stopped then
            return "stopped"
        else
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
            
            return trackName & "||" & trackArtist & "||" & trackAlbum & "||" & (trackDuration as string) & "||" & (trackPosition as string) & "||" & playerState & "||" & trackId
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
                return "Automation permission denied. Please grant Lyra control permission in 'System Settings > Privacy & Security > Automation' for your Terminal application."
            case .invalidResponse:
                return "Failed to parse metadata returned by Spotify AppleScript."
            }
        }
    }

    public init() {}

    /// Fetches the current playback status of Spotify.
    /// - Returns: A strongly typed `SpotifyState` representing the player.
    public func fetchCurrentState() async throws -> SpotifyState {
        // 1. Check if Spotify is running (prevents unsolicited launches of the app)
        let isRunningStr = try await executeAppleScript(Self.isRunningScript)
        guard isRunningStr.trimmingCharacters(in: .whitespacesAndNewlines) == "true" else {
            return .notRunning
        }

        // 2. Query Spotify for track details and playback position
        let stateStr: String
        do {
            stateStr = try await executeAppleScript(Self.getPlaybackStateScript).trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            // If the script execution failed, we might not be sure what is playing.
            // Let's query player state directly to see if it is playing.
            let pState = (try? await executeAppleScript("tell application \"Spotify\" to player state as string").trimmingCharacters(in: .whitespacesAndNewlines)) ?? "stopped"
            if pState == "playing" {
                let track = SpotifyTrack(title: "Advertisement??", artist: "", album: "", duration: 0.0)
                return .playing(track: track, position: 0.0)
            } else {
                return .stopped
            }
        }

        if stateStr == "stopped" {
            return .stopped
        }

        let parts = stateStr.components(separatedBy: "||")
        guard parts.count == 7 else {
            let pState = (try? await executeAppleScript("tell application \"Spotify\" to player state as string").trimmingCharacters(in: .whitespacesAndNewlines)) ?? "stopped"
            if pState == "playing" {
                let track = SpotifyTrack(title: "Advertisement??", artist: "", album: "", duration: 0.0)
                return .playing(track: track, position: 0.0)
            } else {
                return .stopped
            }
        }

        let title = parts[0]
        let artist = parts[1]
        let album = parts[2]
        
        guard let durationMs = Double(parts[3]),
              let positionSec = Double(parts[4]) else {
            let playerState = parts[5]
            if playerState == "playing" {
                let track = SpotifyTrack(title: "Advertisement??", artist: "", album: "", duration: 0.0)
                return .playing(track: track, position: 0.0)
            } else {
                return .stopped
            }
        }

        // Spotify AppleScript duration returns milliseconds; convert to seconds
        let durationSec = durationMs / 1000.0
        let playerState = parts[5]
        let trackId = parts[6]

        // Detect if it is an advertisement, or if we are not sure what is playing.
        // We classify it as an ad if:
        // - the track ID has an ad prefix/marker
        // - the title is empty
        // - the track ID is empty
        // - the track ID does not correspond to a standard song, local file, or podcast episode.
        let isAd = trackId.hasPrefix("spotify:ad") ||
                   trackId.contains(":ad:") ||
                   title.isEmpty ||
                   trackId.isEmpty ||
                   (!trackId.hasPrefix("spotify:track") &&
                    !trackId.hasPrefix("spotify:local") &&
                    !trackId.hasPrefix("spotify:episode"))

        let finalTitle = isAd ? "Advertisement??" : title
        let finalArtist = isAd ? "" : artist
        let finalAlbum = isAd ? "" : album

        let track = SpotifyTrack(
            title: finalTitle,
            artist: finalArtist,
            album: finalAlbum,
            duration: durationSec
        )

        if playerState == "playing" {
            return .playing(track: track, position: positionSec)
        } else {
            return .paused(track: track, position: positionSec)
        }
    }

    /// Safely executes an AppleScript string on the MainActor, converting OS errors to Swift errors.
    @MainActor
    private func executeAppleScript(_ source: String) throws -> String {
        guard let script = NSAppleScript(source: source) else {
            throw SpotifyBridgeError.appleScriptError(code: -1, message: "Could not initialize AppleScript.")
        }

        var errorInfo: NSDictionary? = nil
        let descriptor = script.executeAndReturnError(&errorInfo)

        if let errorInfo = errorInfo {
            let code = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? -1
            let message = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "Unknown AppleScript Error"
            
            // Code -1743 represents OS-level block of automation event permissions.
            if code == -1743 {
                throw SpotifyBridgeError.permissionDenied
            }
            throw SpotifyBridgeError.appleScriptError(code: code, message: message)
        }

        guard let stringValue = descriptor.stringValue else {
            throw SpotifyBridgeError.invalidResponse
        }

        return stringValue
    }
}
