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

extension SpotifyBridge {
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
