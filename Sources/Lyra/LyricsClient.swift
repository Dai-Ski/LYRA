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

        // Fallback: try LRCLIB get without album constraint
        if !album.isEmpty {
            if let lrc = await tryLRCLIBGet(track: cleanTrack, artist: cleanArtist,
                                             album: "", duration: duration,
                                             maxRetries: maxRetries, debug: debug) {
                if debug { print("[LYRA] ✓ LRCLIB get (no album filter) succeeded") }
                let parsed   = parseLyrics(lrc)
                let romanized = generateRomanized(parsed)
                return (original: parsed, romanized: romanized)
            }
        }

        // ── Source 2: LRCLIB /api/search (fuzzy) ──────────────────────────────
        if debug { print("[LYRA] Trying LRCLIB search: '\(cleanTrack)' by '\(cleanArtist)'") }
        if let lrc = await tryLRCLIBSearch(track: cleanTrack, artist: cleanArtist, targetDuration: duration, debug: debug) {
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
            #"\s*-\s*remaster.*"#,
            #"\s*-\s*live.*"#,
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

    private func tryLRCLIBSearch(track: String, artist: String, targetDuration: Double, debug: Bool) async -> String? {
        // Try "track artist" combined query, then track-only
        let queries = [
            "\(track) \(artist)",
            track
        ]
        for q in queries {
            if let result = await lrclibSearch(query: q, track: track, artist: artist, targetDuration: targetDuration, debug: debug) {
                return result
            }
        }
        return nil
    }

    private func lrclibSearch(query: String, track: String, artist: String, targetDuration: Double, debug: Bool) async -> String? {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        struct SearchHit: Decodable {
            let id: Int?
            let artistName:   String?
            let trackName:    String?
            let albumName:    String?
            let duration:     Double?
            let syncedLyrics: String?
            let plainLyrics:  String?
        }

        guard let hits = try? JSONDecoder().decode([SearchHit].self, from: data),
              !hits.isEmpty else { return nil }

        var bestHit: SearchHit? = nil
        var bestScore: Double = -1000.0

        let cleanTrackLow  = track.lowercased()
        let cleanArtistLow = artist.lowercased()

        for hit in hits {
            let hitTrack  = cleanTitle(hit.trackName  ?? "").lowercased()
            let hitArtist = cleanTitle(hit.artistName ?? "").lowercased()
            let hasSynced = hit.syncedLyrics != nil && !(hit.syncedLyrics!.isEmpty)
            let hasPlain  = hit.plainLyrics  != nil && !(hit.plainLyrics!.isEmpty)

            if !hasSynced && !hasPlain { continue }

            var score: Double = 0.0

            // 1. Synced lyrics bonus
            if hasSynced { score += 50.0 }

            // 2. Track title matching
            if hitTrack == cleanTrackLow {
                score += 40.0
            } else if hitTrack.contains(cleanTrackLow) || cleanTrackLow.contains(hitTrack) {
                score += 20.0
            } else {
                let firstWord = cleanTrackLow.components(separatedBy: " ").first ?? cleanTrackLow
                if hitTrack.contains(firstWord) {
                    score += 10.0
                } else {
                    score -= 30.0
                }
            }

            // 3. Artist title matching
            if hitArtist == cleanArtistLow {
                score += 30.0
            } else if hitArtist.contains(cleanArtistLow) || cleanArtistLow.contains(hitArtist) {
                score += 15.0
            }

            // 4. Duration matching (critical for correct timestamp sync)
            if let hitDur = hit.duration, targetDuration > 0 {
                let durDiff = abs(hitDur - targetDuration)
                if durDiff <= 2.0 {
                    score += 50.0
                } else if durDiff <= 5.0 {
                    score += 30.0
                } else if durDiff <= 10.0 {
                    score += 10.0
                } else if durDiff > 20.0 {
                    score -= 60.0
                }
            }

            if score > bestScore {
                bestScore = score
                bestHit = hit
            }
        }

        if let best = bestHit, bestScore > 0 {
            if let synced = best.syncedLyrics, !synced.isEmpty { return synced }
            if let plain  = best.plainLyrics,  !plain.isEmpty  { return plain  }
        }

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

    // MARK: - Romanization (Multi-script Engine)

    func romanize(_ text: String) -> String {
        return Romanizer.romanizeText(text)
    }

    private func generateRomanized(_ lines: [LyricLine]) -> [LyricLine] {
        return Romanizer.romanizeLines(lines)
    }

    // MARK: - LRC Parser

    /// Parses the raw lyrics string (LRC format or plain text) into chronological LyricLines.
    func parseLyrics(_ content: String) -> [LyricLine] {
        let rawLines = content.components(separatedBy: .newlines)
        var lines: [LyricLine] = []
        var globalOffsetSeconds: Double = 0.0

        let offsetRegex = try? NSRegularExpression(pattern: #"\[offset:\s*([+-]?\d+)\]"#, options: .caseInsensitive)
        let timeRegex   = try? NSRegularExpression(pattern: #"\[(\d+):(\d+)(?:[\.:](\d+))?\]"#)

        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // Extract [offset: ms] if present
            if let offsetRegex = offsetRegex {
                let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
                if let match = offsetRegex.firstMatch(in: trimmed, range: nsRange),
                   let msRange = Range(match.range(at: 1), in: trimmed),
                   let ms = Double(trimmed[msRange]) {
                    globalOffsetSeconds = ms / 1000.0
                    continue
                }
            }

            guard let timeRegex = timeRegex else { continue }
            let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
            let matches = timeRegex.matches(in: trimmed, range: nsRange)

            if !matches.isEmpty {
                // Strip out all time brackets to leave clean lyric text
                var lyricText = timeRegex.stringByReplacingMatches(in: trimmed, range: nsRange, withTemplate: "").trimmingCharacters(in: .whitespaces)
                
                if lyricText.hasPrefix("[") && lyricText.hasSuffix("]") && !lyricText.contains(":") {
                    lyricText = ""
                }

                for match in matches {
                    guard let minRange = Range(match.range(at: 1), in: trimmed),
                          let secRange = Range(match.range(at: 2), in: trimmed),
                          let minVal = Double(trimmed[minRange]),
                          let secVal = Double(trimmed[secRange]) else { continue }

                    var subVal = 0.0
                    if match.numberOfRanges > 3, let subRange = Range(match.range(at: 3), in: trimmed) {
                        let subStr = String(trimmed[subRange])
                        if let num = Double(subStr) {
                            if subStr.count == 1 {
                                subVal = num / 10.0
                            } else if subStr.count == 2 {
                                subVal = num / 100.0
                            } else {
                                subVal = num / 1000.0
                            }
                        }
                    }

                    let timestamp = (minVal * 60.0) + secVal + subVal + globalOffsetSeconds
                    lines.append(LyricLine(timestamp: max(0.0, timestamp), text: lyricText))
                }
            }
        }

        if !lines.isEmpty {
            return lines.sorted { $0.timestamp < $1.timestamp }
        }

        // Plain text fallback
        lines.append(LyricLine(timestamp: -1.0, text: "♪ Lyrics (not time-synced)"))
        var validIndex = 0
        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") && trimmed.contains(":") { continue }
            if !trimmed.isEmpty {
                lines.append(LyricLine(timestamp: Double(validIndex) * 4.0, text: trimmed))
                validIndex += 1
            }
        }
        return lines
    }
}