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
}