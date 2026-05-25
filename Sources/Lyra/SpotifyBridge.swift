import Foundation

/// A component that queries Spotify on macOS using AppleScript.
public struct SpotifyBridge: Sendable {
    
    // AppleScript command to verify if Spotify is running without launching it.
    private static let isRunningScript = """
    tell application "System Events"
        return exists (processes where name is "Spotify")
    end tell
    """

    public enum SpotifyBridgeError: LocalizedError {
        case spotifyNotRunning
        case appleScriptError(code: Int, message: String)
        case permissionDenied
        case invalidResponse
    }

    public init() {}
}
