import Foundation

/// Represents a single synchronized lyric line.
public struct LyricLine: Codable, Equatable, Sendable {
    public let timestamp: TimeInterval // in seconds
    public let text: String

    public init(timestamp: TimeInterval, text: String) {
        self.timestamp = timestamp
        self.text = text
    }
}

/// Represents metadata for a music track.
public struct MusicTrack: Equatable, Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let duration: TimeInterval // in seconds

    public init(title: String, artist: String, album: String, duration: TimeInterval) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
    }
    
    public var trackKey: String {
        guard !title.isEmpty || !artist.isEmpty else { return "" }
        return "\(artist) - \(title)"
    }
}

/// Represents the current playback state of a music player.
public enum MusicPlayerState: Equatable, Sendable {
    case notRunning
    case stopped
    case paused(track: MusicTrack, position: TimeInterval)
    case playing(track: MusicTrack, position: TimeInterval)
}

/// Describes the status of the lyrics retrieval.
public enum LyricsStatus: Equatable, Sendable {
    case none
    case loading
    case loaded
    case notFound
    case error(String)
}

/// Represents a snapshot of the current application playback state.
public struct AppPlaybackState: Sendable, Equatable {
    public var isMusicRunning: Bool = false
    public var isPlaying: Bool = false
    public var title: String = ""
    public var artist: String = ""
    public var album: String = ""
    public var position: TimeInterval = 0.0
    public var duration: TimeInterval = 0.0
    public var lastUpdated: Date = Date()
    
    public init() {}
    
    public var trackKey: String {
        guard !title.isEmpty || !artist.isEmpty else { return "" }
        return "\(artist) - \(title)"
    }
}

/// Supported lyric display modes.
public enum LyricMode: String, Codable, Sendable {
    case original
    case romanized
}

/// A thread-safe Actor that coordinates playback state and lyric caching.
public actor AppStateActor {
    private var currentState = AppPlaybackState()
    
    // Active lyrics currently displayed (based on active lyric mode)
    private var activeLyrics: [LyricLine] = []
    private var lyricsStatus: LyricsStatus = .none
    private var currentLyricMode: LyricMode = .original
    
    // Caches for each type of lyrics
    private var originalCache: [String: [LyricLine]] = [:]
    private var romanizedCache: [String: [LyricLine]] = [:]
    
    public init() {}
    
    /// Retrieves a copy of the current playback state.
    public func getState() -> AppPlaybackState {
        return currentState
    }
    
    /// Retrieves the current lyrics, status, mode, and list of available modes.
    public func getLyrics() -> (lyrics: [LyricLine], status: LyricsStatus, mode: LyricMode, availableModes: [LyricMode]) {
        let key = currentState.trackKey
        var modes: [LyricMode] = [.original]
        if let rom = romanizedCache[key], !rom.isEmpty {
            modes.append(.romanized)
        }
        return (activeLyrics, lyricsStatus, currentLyricMode, modes)
    }
    
    /// Changes the active lyric mode.
    public func setLyricMode(_ mode: LyricMode) {
        currentLyricMode = mode
        refreshActiveLyrics()
    }
    
    private func refreshActiveLyrics() {
        let key = currentState.trackKey
        guard currentState.isMusicRunning && !key.isEmpty else {
            activeLyrics = []
            lyricsStatus = .none
            return
        }
        
        switch currentLyricMode {
        case .original:
            activeLyrics = originalCache[key] ?? []
        case .romanized:
            activeLyrics = romanizedCache[key] ?? []
            if activeLyrics.isEmpty {
                activeLyrics = originalCache[key] ?? [] // fallback
            }
        }
        
        if originalCache[key] != nil {
            lyricsStatus = .loaded
        }
    }
    
    /// Updates the playback state. Triggered by the music player polling loop.
    public func updatePlayback(
        isMusicRunning: Bool,
        isPlaying: Bool,
        title: String,
        artist: String,
        album: String,
        position: TimeInterval,
        duration: TimeInterval
    ) {
        let oldKey = currentState.trackKey
        let oldRunning = currentState.isMusicRunning
        
        currentState.isMusicRunning = isMusicRunning
        currentState.isPlaying = isPlaying
        currentState.title = title
        currentState.artist = artist
        currentState.album = album
        currentState.position = position
        currentState.duration = duration
        currentState.lastUpdated = Date()
        
        // If track changed, manage cached lyrics transition
        if isMusicRunning && (!title.isEmpty || !artist.isEmpty) {
            let newKey = currentState.trackKey
            if oldKey != newKey || !oldRunning {
                refreshActiveLyrics()
                if activeLyrics.isEmpty {
                    lyricsStatus = .none
                }
            }
        } else {
            activeLyrics = []
            lyricsStatus = .none
        }
    }
    
    /// Marks lyrics as currently loading.
    public func setLyricsLoading() {
        lyricsStatus = .loading
    }
    
    /// Sets loaded lyrics for a given track, updating the active lyrics if the track is still current.
    public func setLyricsLoaded(
        original: [LyricLine],
        romanized: [LyricLine],
        forKey key: String
    ) {
        originalCache[key] = original
        romanizedCache[key] = romanized
        
        if currentState.trackKey == key {
            refreshActiveLyrics()
            lyricsStatus = .loaded
        }
    }
    
    /// Marks lyrics as not found, caching this state to prevent redundant requests.
    public func setLyricsNotFound(forKey key: String) {
        originalCache[key] = []
        romanizedCache[key] = []
        
        if currentState.trackKey == key {
            activeLyrics = []
            lyricsStatus = .notFound
        }
    }
    
    /// Handles lyric loading error, setting status appropriately.
    public func setLyricsError(_ errorMessage: String, forKey key: String) {
        if currentState.trackKey == key {
            lyricsStatus = .error(errorMessage)
        }
    }
}