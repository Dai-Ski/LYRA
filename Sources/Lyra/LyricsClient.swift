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

        guard let hits = try? JSONDecoder().decode([SearchHit].self, from: data),
              !hits.isEmpty else { return nil }

        // Score hits: prefer ones whose track/artist name fuzzy-matches ours
        let cleanTrackLow  = track.lowercased()
        let cleanArtistLow = artist.lowercased()

        for hit in hits {
            let hitTrack  = (hit.trackName  ?? "").lowercased()
            let hitArtist = (hit.artistName ?? "").lowercased()
            // Must share at least the first meaningful word of the track name
            let firstWord = cleanTrackLow.components(separatedBy: " ").first ?? cleanTrackLow
            guard hitTrack.contains(firstWord) || hitArtist.contains(cleanArtistLow) else { continue }
            if let synced = hit.syncedLyrics, !synced.isEmpty { return synced }
            if let plain  = hit.plainLyrics,  !plain.isEmpty  { return plain  }
        }

        // Last resort: just take the first hit's lyrics
        let first = hits[0]
        if let synced = first.syncedLyrics, !synced.isEmpty { return synced }
        if let plain  = first.plainLyrics,  !plain.isEmpty  { return plain  }
        return nil
    }

    // MARK: - Source 3: JioSaavn (Hindi / Bollywood)

    private func tryJioSaavn(track: String, artist: String, debug: Bool) async -> [LyricLine]? {
        // Try multiple query strategies: "track artist", "track only", "cleaned further"
        let queryVariants: [String] = [
            "\(track) \(artist)",
            track,
            stripParenthesesContent(track)   // e.g. removes "(From Movie)"
        ].filter { !$0.isEmpty }

        for query in queryVariants {
            if let lines = await jioSaavnSearch(query: query, debug: debug) {
                return lines
            }
        }
        return nil
    }

    private func jioSaavnSearch(query: String, debug: Bool) async -> [LyricLine]? {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchURL = URL(string: "https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&_marker=0&cc=in&includeMetaTags=1&q=\(encodedQuery)") else {
            return nil
        }

        var searchReq = URLRequest(url: searchURL)
        searchReq.timeoutInterval = 10.0
        searchReq.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        searchReq.setValue("https://www.jiosaavn.com", forHTTPHeaderField: "Referer")

        guard let (searchData, searchResp) = try? await URLSession.shared.data(for: searchReq),
              let http = searchResp as? HTTPURLResponse, http.statusCode == 200 else {
            if debug { print("[LYRA] JioSaavn search request failed") }
            return nil
        }

        struct SongResult: Decodable {
            let id: String
            let song: String?
            let has_lyrics: String?
        }
        struct SearchPayload: Decodable {
            let results: [SongResult]?
        }

        guard let payload = try? JSONDecoder().decode(SearchPayload.self, from: searchData),
              let results = payload.results, !results.isEmpty else {
            if debug { print("[LYRA] JioSaavn: no results for query '\(query)'") }
            return nil
        }

        // Prefer a result that has lyrics; fall back to first result regardless
        let withLyrics    = results.first { ($0.has_lyrics ?? "").lowercased() == "true" }
        let candidateSong = withLyrics ?? results.first

        guard let song = candidateSong else { return nil }
        if debug {
            print("[LYRA] JioSaavn found: '\(song.song ?? "?")' (has_lyrics=\(song.has_lyrics ?? "?"))")
        }

        return await jioSaavnFetchLyrics(songId: song.id, debug: debug)
    }

    private func jioSaavnFetchLyrics(songId: String, debug: Bool) async -> [LyricLine]? {
        guard let lyricURL = URL(string: "https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&_format=json&_marker=0&cc=in&includeMetaTags=1&lyrics_id=\(songId)") else {
            return nil
        }

        var lyricReq = URLRequest(url: lyricURL)
        lyricReq.timeoutInterval = 10.0
        lyricReq.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        lyricReq.setValue("https://www.jiosaavn.com", forHTTPHeaderField: "Referer")

        guard let (lyricData, lyricResp) = try? await URLSession.shared.data(for: lyricReq),
              let http = lyricResp as? HTTPURLResponse, http.statusCode == 200 else {
            if debug { print("[LYRA] JioSaavn lyric fetch failed for id \(songId)") }
            return nil
        }

        struct LyricPayload: Decodable {
            let lyrics: String?
        }

        guard let payload = try? JSONDecoder().decode(LyricPayload.self, from: lyricData),
              let raw = payload.lyrics, !raw.isEmpty else {
            if debug { print("[LYRA] JioSaavn: empty lyrics for id \(songId)") }
            return nil
        }

        // Clean HTML <br> tags
        let clean = raw
            .replacingOccurrences(of: "<br>",   with: "\n")
            .replacingOccurrences(of: "<br/>",  with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#039;", with: "'")

        return plainTextToLines(clean, source: "JioSaavn")
    }

    // MARK: - Source 4: lyrics.ovh

    private func tryLyricsOVH(track: String, artist: String, debug: Bool) async -> [LyricLine]? {
        // URL-encode artist and title separately for path segments
        guard let encArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let encTrack  = track.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.lyrics.ovh/v1/\(encArtist)/\(encTrack)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            if debug { print("[LYRA] lyrics.ovh request failed") }
            return nil
        }

        struct OVHPayload: Decodable {
            let lyrics: String?
        }

        guard let payload = try? JSONDecoder().decode(OVHPayload.self, from: data),
              let raw = payload.lyrics, !raw.isEmpty else {
            if debug { print("[LYRA] lyrics.ovh: empty/no lyrics") }
            return nil
        }

        return plainTextToLines(raw, source: "lyrics.ovh")
    }

    // MARK: - Helpers

    /// Converts a plain-text multi-line string into a timed [LyricLine] array.
    private func plainTextToLines(_ text: String, source: String) -> [LyricLine]? {
        let rawLines = text.components(separatedBy: .newlines)
        var lines: [LyricLine] = []
        var idx = 0
        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                lines.append(LyricLine(timestamp: Double(idx) * 4.0, text: trimmed))
                idx += 1
            }
        }
        guard !lines.isEmpty else { return nil }
        // Prepend a note that lyrics are not synced
        lines.insert(LyricLine(timestamp: -1.0, text: "♪ Lyrics (not time-synced)"), at: 0)
        return lines
    }

    /// Removes anything inside parentheses or brackets entirely.
    private func stripParenthesesContent(_ text: String) -> String {
        var s = text
        for pattern in [#"\([^)]*\)"#, #"\[[^\]]*\]"#] {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(s.startIndex..., in: s)
                s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
            }
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Romanization (kept for optional mode)

    func romanize(_ text: String) -> String {
        let mutableString = NSMutableString(string: text)
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
        return mutableString as String
    }

    private func generateRomanized(_ lines: [LyricLine]) -> [LyricLine] {
        var romanized: [LyricLine] = []
        var hasChanges = false
        for line in lines {
            let romanizedText = romanize(line.text)
            if romanizedText != line.text { hasChanges = true }
            romanized.append(LyricLine(timestamp: line.timestamp, text: romanizedText))
        }
        return hasChanges ? romanized : []
    }

    // MARK: - LRC Parser

    /// Parses the raw lyrics string (LRC format or plain text) into chronological LyricLines.
    func parseLyrics(_ content: String) -> [LyricLine] {
        let rawLines = content.components(separatedBy: .newlines)
        var lines: [LyricLine] = []

        // Detect if the payload contains synchronized tags e.g. [00:12.34]
        var isSynced = false
        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") && trimmed.contains("]") {
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
                guard trimmed.hasPrefix("["),
                      let closingBracketIndex = trimmed.firstIndex(of: "]") else { continue }

                let timestampPart = trimmed[trimmed.index(after: trimmed.startIndex)..<closingBracketIndex]
                let lyricPart     = trimmed[trimmed.index(after: closingBracketIndex)...].trimmingCharacters(in: .whitespaces)

                let timeComponents = timestampPart.split(separator: ":")
                guard timeComponents.count == 2,
                      let minutes = Double(timeComponents[0]),
                      let seconds = Double(timeComponents[1]) else { continue }

                let totalSeconds = (minutes * 60.0) + seconds
                lines.append(LyricLine(timestamp: totalSeconds, text: lyricPart))
            }
        } else {
            // Plain text: spread lines out by 4 seconds
            lines.append(LyricLine(timestamp: -1.0, text: "♪ Lyrics (not time-synced)"))
            var validIndex = 0
            for rawLine in rawLines {
                let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    lines.append(LyricLine(timestamp: Double(validIndex) * 4.0, text: trimmed))
                    validIndex += 1
                }
            }
        }

        return lines.sorted { $0.timestamp < $1.timestamp }
    }
}