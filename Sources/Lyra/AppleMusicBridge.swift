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

    /// Fetches the current playback status of Apple Music.
    /// - Parameter isRunning: Boolean representing if Apple Music is currently running.
    /// - Returns: A strongly typed `MusicPlayerState` representing the player.
    public func fetchCurrentState(isRunning: Bool) async throws -> MusicPlayerState {
        guard isRunning else { return .notRunning }

        let stateStr: String
        do {
            stateStr = try await executeAppleScript(Self.getPlaybackStateScript)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            // Script failed — do a minimal state check to avoid crashing
            let pState = (try? await executeAppleScript(
                "tell application \"Music\" to player state as string"
            ).trimmingCharacters(in: .whitespacesAndNewlines)) ?? "stopped"
            return pState == "playing"
                ? .playing(track: MusicTrack(title: "Unknown Track", artist: "", album: "", duration: 0.0), position: 0.0)
                : .stopped
        }

        if stateStr == "stopped" { return .stopped }

        // Split on ASCII unit separator (0x1F) — safe against special chars in metadata
        let sep = "\u{1F}"
        let parts = stateStr.components(separatedBy: sep)

        guard parts.count == 7 else {
            // Unexpected format — minimal fallback
            let pState = (try? await executeAppleScript(
                "tell application \"Music\" to player state as string"
            ).trimmingCharacters(in: .whitespacesAndNewlines)) ?? "stopped"
            return pState == "playing"
                ? .playing(track: MusicTrack(title: "Unknown Track", artist: "", album: "", duration: 0.0), position: 0.0)
                : .stopped
        }

        let title       = parts[0].trimmingCharacters(in: .whitespaces)
        let artist      = parts[1].trimmingCharacters(in: .whitespaces)
        let album       = parts[2].trimmingCharacters(in: .whitespaces)
        let playerState = parts[5].trimmingCharacters(in: .whitespaces)
        let trackKind   = parts[6].trimmingCharacters(in: .whitespaces).lowercased()

        // Apple Music returns duration already in seconds (as a decimal float)
        // Use 0.0 as fallback if parsing fails (e.g. radio streams)
        let durationSec  = Double(parts[3]) ?? 0.0
        let positionSec  = Double(parts[4]) ?? 0.0

        // Detect radio streams / internet radio (no duration, or kind contains "internet audio stream")
        let isStream = durationSec <= 0 || trackKind.contains("internet") || trackKind.contains("stream")

        let finalTitle  = title.isEmpty ? (isStream ? "Radio Stream" : "Unknown Track") : title
        let finalArtist = isStream ? "" : artist

        let track = MusicTrack(
            title: finalTitle,
            artist: finalArtist,
            album: album,
            duration: durationSec
        )

        if playerState == "playing" {
            return .playing(track: track, position: positionSec)
        } else {
            return .paused(track: track, position: positionSec)
        }
    }

    /// Safely executes an AppleScript string on the MainActor.
    @MainActor
    private func executeAppleScript(_ source: String) throws -> String {
        guard let script = NSAppleScript(source: source) else {
            throw AppleMusicBridgeError.appleScriptError(code: -1, message: "Could not initialize AppleScript.")
        }

        var errorInfo: NSDictionary? = nil
        let descriptor = script.executeAndReturnError(&errorInfo)

        if let errorInfo = errorInfo {
            let code    = (errorInfo[NSAppleScript.errorNumber]  as? Int)    ?? -1
            let message = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "Unknown AppleScript Error"
            if code == -1743 { throw AppleMusicBridgeError.permissionDenied }
            throw AppleMusicBridgeError.appleScriptError(code: code, message: message)
        }

        guard let stringValue = descriptor.stringValue else {
            throw AppleMusicBridgeError.invalidResponse
        }

        return stringValue
    }
}