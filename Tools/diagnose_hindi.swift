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

guard let track = getTrackInfo() else {
    print("No active track playing.")
    exit(0)
}

print("Active Track:")
print("  Raw Title: \(track.title)")
print("  Raw Artist: \(track.artist)")

let cleanTitle = cleanQueryString(track.title)
let cleanArtist = cleanQueryString(track.artist)
print("  Cleaned Title: \(cleanTitle)")
print("  Cleaned Artist: \(cleanArtist)")

// Test both queries
let queries = [
    "\(track.title) \(track.artist)",
    "\(cleanTitle) \(cleanArtist)",
    "\(cleanTitle)",
    "\(track.title)"
]

let semaphore = DispatchSemaphore(value: 0)

func tryQuery(q: String, completion: @escaping () -> Void) {
    guard let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
        completion()
        return
    }
    let urlString = "https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&_marker=0&cc=in&includeMetaTags=1&q=\(encoded)"
    let url = URL(string: urlString)!
    
    var request = URLRequest(url: url)
    request.timeoutInterval = 8.0
    
    print("\nTrying query: '\(q)'...")
    URLSession.shared.dataTask(with: request) { data, response, error in
        defer { completion() }
        if let error = error {
            print("  Error: \(error.localizedDescription)")
            return
        }
        guard let data = data else {
            print("  No data received")
            return
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]], !results.isEmpty {
                print("  Success! Found \(results.count) results.")
                for (idx, song) in results.prefix(3).enumerated() {
                    let sName = song["song"] as? String ?? ""
                    let sId = song["id"] as? String ?? ""
                    let sArtists = song["primary_artists"] as? String ?? ""
                    let hasLyr = song["has_lyrics"] as? String ?? ""
                    print("    [\(idx + 1)] Song: \(sName) | Artist: \(sArtists) | ID: \(sId) | HasLyrics: \(hasLyr)")
                }
            } else {
                print("  No results found.")
            }
        } catch {
            print("  JSON Parse error: \(error.localizedDescription)")
        }
    }.resume()
}

var idx = 0
func runNext() {
    if idx >= queries.count {
        semaphore.signal()
        return
    }
    let q = queries[idx]
    idx += 1
    tryQuery(q: q) {
        runNext()
    }
}

runNext()
semaphore.wait()
exit(0)