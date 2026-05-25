import Foundation

/// Error states returned by the LRCLIB Client.
public enum LyricsError: LocalizedError, Sendable {
    case invalidURL
    case notFound
    case rateLimited
    case serverError(statusCode: Int)
    case networkError(String)
    case decodeError(String)
    case malformedResponse
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid request URL."
        case .notFound: return "No lyrics found on LRCLIB."
        case .rateLimited: return "Rate limited by LRCLIB. Please slow down."
        case .serverError(let code): return "LRCLIB server returned error (HTTP \(code))."
        case .networkError(let msg): return "Network connection error: \(msg)"
        case .decodeError(let msg): return "Failed to parse API response: \(msg)"
        case .malformedResponse: return "Received malformed API response."
        }
    }
}

/// A lightweight, Sendable client to interact with the lrclib.net API.
public struct LyricsClient: Sendable {
    
    private let userAgent = "LyraSpotifyLyricsCLI/1.0 (macOS; Swift)"
    
    public init() {}
    
    /// Fetches lyrics with exponential backoff retries.
    /// - Parameters:
    ///   - track: Track title.
    ///   - artist: Artist name.
    ///   - album: Album name (optional).
    ///   - duration: Track duration in seconds (optional).
    ///   - maxRetries: Maximum number of retries for transient errors.
    ///   - debug: Whether to output debug statements.
    /// - Returns: A parsed list of `LyricLine`s.
    public func fetchLyrics(
        track: String,
        artist: String,
        album: String,
        duration: Double,
        maxRetries: Int = 3,
        debug: Bool = false
    ) async throws -> [LyricLine] {
        var attempt = 0
        var delay: TimeInterval = 1.0
        
        while true {
            do {
                if debug {
                    print("[DEBUG] Fetching lyrics (attempt \(attempt + 1))...")
                }
                let rawLrc = try await performFetch(track: track, artist: artist, album: album, duration: duration)
                return parseLyrics(rawLrc)
            } catch let error as LyricsError {
                // Do not retry on non-transient errors like "NotFound" or "Invalid URL"
                if case .notFound = error {
                    throw error
                }
                
                attempt += 1
                if attempt >= maxRetries {
                    throw error
                }
                
                if debug {
                    print("[DEBUG] Transient error occurred: \(error.localizedDescription). Retrying in \(delay)s...")
                }
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay *= 2.0 // Exponential backoff
            } catch {
                attempt += 1
                if attempt >= maxRetries {
                    throw LyricsError.networkError(error.localizedDescription)
                }
                
                if debug {
                    print("[DEBUG] Request failed: \(error.localizedDescription). Retrying in \(delay)s...")
                }
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay *= 2.0
            }
        }
    }
    
    /// Queries the API and returns the raw synchronized LRC contents or plain text fallback.
    private func performFetch(track: String, artist: String, album: String, duration: Double) async throws -> String {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        var queryItems = [
            URLQueryItem(name: "track_name", value: track),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        
        if !album.isEmpty {
            queryItems.append(URLQueryItem(name: "album_name", value: album))
        }
        if duration > 0 {
            // LRCLIB duration parameter is integer seconds
            queryItems.append(URLQueryItem(name: "duration", value: String(Int(duration))))
        }
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw LyricsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0 // 8 seconds timeout per attempt
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LyricsError.networkError(error.localizedDescription)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LyricsError.malformedResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            struct LRCLyrics: Decodable {
                let syncedLyrics: String?
                let plainLyrics: String?
            }
            do {
                let decoded = try JSONDecoder().decode(LRCLyrics.self, from: data)
                if let synced = decoded.syncedLyrics, !synced.isEmpty {
                    return synced
                } else if let plain = decoded.plainLyrics, !plain.isEmpty {
                    return plain
                } else {
                    throw LyricsError.notFound
                }
            } catch {
                throw LyricsError.decodeError(error.localizedDescription)
            }
        case 404:
            throw LyricsError.notFound
        case 429:
            throw LyricsError.rateLimited
        default:
            throw LyricsError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    /// Parses the raw lyrics string (LRC format or plain text) into chronological LyricLines.
    private func parseLyrics(_ content: String) -> [LyricLine] {
        let rawLines = content.components(separatedBy: .newlines)
        var lines: [LyricLine] = []
        
        // Detect if the payload actually contains synchronized tags e.g. [00:12.34]
        var isSynced = false
        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") && trimmed.contains("]") {
                // Confirm there is a colon inside the brackets to avoid metadata tags like [offset:0]
                if let closeBracket = trimmed.firstIndex(of: "]"),
                   trimmed[..<closeBracket].contains(":") {
                    isSynced = true
                    break
                }
            }
        }
        
        if isSynced {
            for rawLine in rawLines {
                let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("["), let closingBracketIndex = trimmed.firstIndex(of: "]") else {
                    continue
                }
                
                let timestampPart = trimmed[trimmed.index(after: trimmed.startIndex)..<closingBracketIndex]
                let lyricPart = trimmed[trimmed.index(after: closingBracketIndex)...].trimmingCharacters(in: .whitespaces)
                
                // Parse timestamp format "mm:ss.xx" or "m:ss.xxx" etc.
                let timeComponents = timestampPart.split(separator: ":")
                guard timeComponents.count == 2 else { continue }
                
                guard let minutes = Double(timeComponents[0]),
                      let seconds = Double(timeComponents[1]) else {
                    continue
                }
                
                let totalSeconds = (minutes * 60.0) + seconds
                lines.append(LyricLine(timestamp: totalSeconds, text: lyricPart))
            }
        } else {
            // For plain text, add a notice and spread the lines out by 4 seconds
            // to make them scrollable and readable in the TUI window.
            lines.append(LyricLine(timestamp: 0.0, text: "[Synced lyrics not available. Displaying plain text]"))
            var validIndex = 0
            for rawLine in rawLines {
                let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    lines.append(LyricLine(timestamp: Double(validIndex + 1) * 4.0, text: trimmed))
                    validIndex += 1
                }
            }
        }
        
        return lines.sorted { $0.timestamp < $1.timestamp }
    }
}
