import Foundation
import AppKit

func executeAppleScript(_ source: String) -> String? {
    guard let script = NSAppleScript(source: source) else { return nil }
    var errorInfo: NSDictionary? = nil
    let descriptor = script.executeAndReturnError(&errorInfo)
    if errorInfo != nil { return nil }
    return descriptor.stringValue
}

func getRunningApps() -> (spotify: Bool, music: Bool) {
    let runningApps = NSWorkspace.shared.runningApplications
    var spotify = false
    var music = false
    for app in runningApps {
        if app.bundleIdentifier == "com.spotify.client" {
            spotify = true
        } else if app.bundleIdentifier == "com.apple.Music" {
            music = true
        }
    }
    return (spotify, music)
}

func getTrackInfo() -> (title: String, artist: String, album: String, duration: Double)? {
    let (spotify, music) = getRunningApps()
    
    if spotify {
        let script = """
        tell application "Spotify"
            if player state is not stopped then
                return name of current track & "||" & artist of current track & "||" & album of current track & "||" & (duration of current track as string)
            end if
        end tell
        """
        if let res = executeAppleScript(script), !res.isEmpty {
            let parts = res.components(separatedBy: "||")
            if parts.count == 4 {
                let durationMs = Double(parts[3]) ?? 0.0
                return (parts[0], parts[1], parts[2], durationMs / 1000.0)
            }
        }
    }
    
    if music {
        let script = """
        tell application "Music"
            if player state is not stopped then
                return name of current track & "||" & artist of current track & "||" & album of current track & "||" & (duration of current track as string)
            end if
        end tell
        """
        if let res = executeAppleScript(script), !res.isEmpty {
            let parts = res.components(separatedBy: "||")
            if parts.count == 4 {
                let durationSec = Double(parts[3]) ?? 0.0
                return (parts[0], parts[1], parts[2], durationSec)
            }
        }
    }
    
    return nil
}

func cleanQueryString(_ str: String) -> String {
    // 1. Remove extra info in parentheses or brackets like "(From ...)", "[Lofi ...]", "(feat. ...)"
    var cleaned = str
    
    // Pattern to match parentheses or brackets starting with common noise words
    let patterns = [
        "\\s*\\([^)]*\\)", // remove anything in parentheses
        "\\s*\\[[^\\]]*\\]" // remove anything in square brackets
    ]
    
    for pattern in patterns {
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: cleaned.utf16.count)
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
        }
    }
    
    // Remove punctuation
    let punctuation = CharacterSet.punctuationCharacters
    cleaned = cleaned.components(separatedBy: punctuation).joined(separator: "")
    
    // Remove extra whitespaces
    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    while cleaned.contains("  ") {
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
    }
    
    return cleaned
}
