import Foundation

func fetchGeniusLyrics(path: String) async throws -> String {
    let url = URL(string: "https://genius.com" + path)!
    var request = URLRequest(url: url)
    request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
    
    let (data, _) = try await URLSession.shared.data(for: request)
    guard let html = String(data: data, encoding: .utf8) else {
        throw NSError(domain: "Genius", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode HTML"])
    }
    
    // Find all <div data-lyrics-container="true"...>...</div> blocks
    var lyrics = ""
    let containerPattern = "<div[^>]*data-lyrics-container=\"true\"[^>]*>(.*?)</div>"
    guard let regex = try? NSRegularExpression(pattern: containerPattern, options: [.dotMatchesLineSeparators]) else {
        throw NSError(domain: "Genius", code: -2, userInfo: [NSLocalizedDescriptionKey: "Regex init failed"])
    }
    
    let range = NSRange(location: 0, length: html.utf16.count)
    let matches = regex.matches(in: html, options: [], range: range)
    
    for match in matches {
        if let subRange = Range(match.range(at: 1), in: html) {
            let containerHTML = String(html[subRange])
            lyrics += containerHTML + "\n"
        }
    }
    
    // Replace <br/>, <br>, <br /> with newlines
    var clean = lyrics
        .replacingOccurrences(of: "<br/>", with: "\n")
        .replacingOccurrences(of: "<br>", with: "\n")
        .replacingOccurrences(of: "<br />", with: "\n")
        .replacingOccurrences(of: "</div>", with: "\n")
        .replacingOccurrences(of: "<div>", with: "")
    
    // Remove other HTML tags (like <a>, <span>, etc.)
    let tagRegex = try! NSRegularExpression(pattern: "<[^>]+>", options: [])
    clean = tagRegex.stringByReplacingMatches(in: clean, options: [], range: NSRange(location: 0, length: clean.utf16.count), withTemplate: "")
    
    // Decode HTML entities (e.g. &#x27; &amp; &quot;)
    clean = clean
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#x27;", with: "'")
        .replacingOccurrences(of: "&apos;", with: "'")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
    
    return clean.trimmingCharacters(in: .whitespacesAndNewlines)
}

func searchGenius(query: String) async throws -> String {
    let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
    let url = URL(string: "https://genius.com/api/search/multi?q=\(encodedQuery)")!
    
    var request = URLRequest(url: url)
    request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
    
    let (data, _) = try await URLSession.shared.data(for: request)
    
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let response = json["response"] as? [String: Any],
          let sections = response["sections"] as? [[String: Any]] else {
        throw NSError(domain: "Genius", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure from Genius"])
    }
    
    for section in sections {
        guard let hits = section["hits"] as? [[String: Any]] else { continue }
        for hit in hits {
            let hitType = hit["type"] as? String ?? ""
            if hitType == "song", let result = hit["result"] as? [String: Any] {
                let path = result["path"] as? String ?? ""
                let title = result["title"] as? String ?? ""
                let artist = result["artist_names"] as? String ?? ""
                print("Found match on Genius: \(title) by \(artist)")
                return path
            }
        }
    }
    
    throw NSError(domain: "Genius", code: -4, userInfo: [NSLocalizedDescriptionKey: "No song found on Genius"])
}

Task {
    do {
        // Query "Dekho Na" by "Raman"
        let path = try await searchGenius(query: "Dekho Na Raman")
        print("Path: \(path)")
        let lyrics = try await fetchGeniusLyrics(path: path)
        print("Lyrics:\n\(lyrics.prefix(600))")
    } catch {
        print("Error: \(error.localizedDescription)")
    }
    exit(0)
}

// Keep command line script alive
dispatchMain()
