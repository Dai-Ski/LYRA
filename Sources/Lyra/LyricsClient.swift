import Foundation

/// Error states returned by the Lyrics Client.
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
        case .invalidURL:            return "Invalid request URL."
        case .notFound:             return "No lyrics found."
        case .rateLimited:          return "Rate limited. Please slow down."
        case .serverError(let c):   return "Server error (HTTP \(c))."
        case .networkError(let m):  return "Network error: \(m)"
        case .decodeError(let m):   return "Failed to parse response: \(m)"
        case .malformedResponse:    return "Received malformed API response."
        }
    }
}

/// A lightweight, Sendable client to interact with multiple lyrics sources.
/// Cascade order: LRCLIB (get) → LRCLIB (search) → JioSaavn → lyrics.ovh
public struct LyricsClient: Sendable {

    private let userAgent = "LyraSpotifyLyricsCLI/1.0 (macOS; Swift)"

    public init() {}

    // MARK: - Public entry point

    /// Fetches lyrics with exponential backoff retries.
    public func fetchLyrics(
        track: String,
        artist: String,
        album: String,
        duration: Double,
        maxRetries: Int = 2,
        debug: Bool = false
    ) async throws -> (original: [LyricLine], romanized: [LyricLine]) {

        // Build a cleaned track/artist pair once, used by multiple sources
        let cleanTrack  = cleanTitle(track)
        let cleanArtist = cleanTitle(artist)

        // ── Source 1: LRCLIB /api/get (exact, with duration) ──────────────────
        if debug { print("[LYRA] Trying LRCLIB get: '\(cleanTrack)' by '\(cleanArtist)'") }
        if let lrc = await tryLRCLIBGet(track: cleanTrack, artist: cleanArtist,
                                         album: album, duration: duration,
                                         maxRetries: maxRetries, debug: debug) {
            if debug { print("[LYRA] ✓ LRCLIB get succeeded") }
            let parsed   = parseLyrics(lrc)
            let romanized = generateRomanized(parsed)
            return (original: parsed, romanized: romanized)
        }

        // ── Source 2: LRCLIB /api/search (fuzzy) ──────────────────────────────
        if debug { print("[LYRA] Trying LRCLIB search: '\(cleanTrack)' by '\(cleanArtist)'") }
        if let lrc = await tryLRCLIBSearch(track: cleanTrack, artist: cleanArtist, debug: debug) {
            if debug { print("[LYRA] ✓ LRCLIB search succeeded") }
            let parsed   = parseLyrics(lrc)
            let romanized = generateRomanized(parsed)
            return (original: parsed, romanized: romanized)
        }

        // ── Source 3: JioSaavn (best for Hindi / Bollywood) ───────────────────
        if debug { print("[LYRA] Trying JioSaavn: '\(cleanTrack)' by '\(cleanArtist)'") }
        if let lines = await tryJioSaavn(track: cleanTrack, artist: cleanArtist, debug: debug) {
            if debug { print("[LYRA] ✓ JioSaavn succeeded") }
            let romanized = generateRomanized(lines)
            return (original: lines, romanized: romanized)
        }

        // ── Source 4: lyrics.ovh ──────────────────────────────────────────────
        if debug { print("[LYRA] Trying lyrics.ovh: '\(cleanTrack)' by '\(cleanArtist)'") }
        if let lines = await tryLyricsOVH(track: cleanTrack, artist: cleanArtist, debug: debug) {
            if debug { print("[LYRA] ✓ lyrics.ovh succeeded") }
            let romanized = generateRomanized(lines)
            return (original: lines, romanized: romanized)
        }

        if debug { print("[LYRA] ✗ All sources exhausted for '\(track)' by '\(artist)'") }
        throw LyricsError.notFound
    }

    // MARK: - Query Cleaning

    /// Strips common noise from track/artist titles to improve API hit rates.
    /// Removes: (feat. ...), [Official Video], - Remastered, etc.
    func cleanTitle(_ title: String) -> String {
        var s = title

        // Remove content in parentheses/brackets that are extras
        // e.g. "(feat. Someone)", "[Official Video]", "(From \"Movie\")"
        let bracketPatterns = [
            #"\s*\(feat\.?[^)]*\)"#,
            #"\s*\[feat\.?[^\]]*\]"#,
            #"\s*\(ft\.?[^)]*\)"#,
            #"\s*\[ft\.?[^\]]*\]"#,
            #"\s*\(with [^)]*\)"#,
            #"\s*\[with [^\]]*\]"#,
            #"\s*\(official[^)]*\)"#,
            #"\s*\[official[^\]]*\]"#,
            #"\s*\(lyric[^)]*\)"#,
            #"\s*\[lyric[^\]]*\]"#,
            #"\s*\(video[^)]*\)"#,
            #"\s*\[video[^\]]*\]"#,
            #"\s*\(audio[^)]*\)"#,
            #"\s*\[audio[^\]]*\]"#,
            #"\s*\(remaster[^)]*\)"#,
            #"\s*\[remaster[^\]]*\]"#,
            #"\s*-\s*remaster\w*"#,
            #"\s*-\s*live\b"#,
        ]
        for pattern in bracketPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(s.startIndex..., in: s)
                s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
            }
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Source 1: LRCLIB /api/get

    private func tryLRCLIBGet(
        track: String, artist: String, album: String, duration: Double,
        maxRetries: Int, debug: Bool
    ) async -> String? {
        var attempt = 0
        var delay: TimeInterval = 1.0
        while attempt < maxRetries {
            do {
                return try await lrclibGet(track: track, artist: artist,
                                           album: album, duration: duration)
            } catch let error as LyricsError {
                if case .notFound = error { return nil }
                if case .rateLimited = error {
                    attempt += 1
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    delay *= 2.0
                    continue
                }
                return nil
            } catch {
                attempt += 1
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay *= 2.0
            }
        }
        return nil
    }

    private func lrclibGet(track: String, artist: String, album: String, duration: Double) async throws -> String {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        var queryItems = [
            URLQueryItem(name: "track_name", value: track),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        if !album.isEmpty {
            queryItems.append(URLQueryItem(name: "album_name", value: album))
        }
        if duration > 0 {
            queryItems.append(URLQueryItem(name: "duration", value: String(Int(duration))))
        }
        components.queryItems = queryItems

        guard let url = components.url else { throw LyricsError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LyricsError.malformedResponse }

        switch http.statusCode {
        case 200:
            struct LRCPayload: Decodable {
                let syncedLyrics: String?
                let plainLyrics:  String?
            }
            let decoded = try JSONDecoder().decode(LRCPayload.self, from: data)
            if let synced = decoded.syncedLyrics, !synced.isEmpty { return synced }
            if let plain  = decoded.plainLyrics,  !plain.isEmpty  { return plain  }
            throw LyricsError.notFound
        case 404: throw LyricsError.notFound
        case 429: throw LyricsError.rateLimited
        default:  throw LyricsError.serverError(statusCode: http.statusCode)
        }
    }

    // MARK: - Source 2: LRCLIB /api/search

    private func tryLRCLIBSearch(track: String, artist: String, debug: Bool) async -> String? {
        // Try "track artist" combined query, then track-only
        let queries = [
            "\(track) \(artist)",
            track
        ]
        for q in queries {
            if let result = await lrclibSearch(query: q, track: track, artist: artist, debug: debug) {
                return result
            }
        }
        return nil
    }

    private func lrclibSearch(query: String, track: String, artist: String, debug: Bool) async -> String? {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        struct SearchHit: Decodable {
            let artistName:   String?
            let trackName:    String?
            let syncedLyrics: String?
            let plainLyrics:  String?
        }

}