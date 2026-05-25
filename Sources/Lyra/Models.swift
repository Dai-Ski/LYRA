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

/// Represents metadata for a Spotify track.
public struct SpotifyTrack: Equatable, Sendable {
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

/// Represents the current playback state of Spotify.
public enum SpotifyState: Equatable, Sendable {
    case notRunning
    case stopped
    case paused(track: SpotifyTrack, position: TimeInterval)
    case playing(track: SpotifyTrack, position: TimeInterval)
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
    public var isSpotifyRunning: Bool = false
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

/// A thread-safe Actor that coordinates playback state and lyric caching.
public actor AppStateActor {
    private var currentState = AppPlaybackState()
    private var currentLyrics: [LyricLine] = []
    private var lyricsStatus: LyricsStatus = .none
    private var lyricsCache: [String: [LyricLine]] = [:]
    
    public init() {}
    
    /// Retrieves a copy of the current playback state.
    public func getState() -> AppPlaybackState {
        return currentState
    }
    
    /// Retrieves the current lyrics and their loading status.
    public func getLyrics() -> ([LyricLine], LyricsStatus) {
        return (currentLyrics, lyricsStatus)
    }
    
    /// Updates the playback state. Triggered by the Spotify polling loop.
    public func updatePlayback(
        isSpotifyRunning: Bool,
        isPlaying: Bool,
        title: String,
        artist: String,
        album: String,
        position: TimeInterval,
        duration: TimeInterval
    ) {
        let oldKey = currentState.trackKey
        let oldRunning = currentState.isSpotifyRunning
        
        currentState.isSpotifyRunning = isSpotifyRunning
        currentState.isPlaying = isPlaying
        currentState.title = title
        currentState.artist = artist
        currentState.album = album
        currentState.position = position
        currentState.duration = duration
        currentState.lastUpdated = Date()
        
        // If track changed, manage cached lyrics transition
        if isSpotifyRunning && (!title.isEmpty || !artist.isEmpty) {
            let newKey = currentState.trackKey
            if oldKey != newKey || !oldRunning {
                if let cached = lyricsCache[newKey] {
                    currentLyrics = cached
                    lyricsStatus = .loaded
                } else {
                    currentLyrics = []
                    lyricsStatus = .none
                }
            }
        } else {
            currentLyrics = []
            lyricsStatus = .none
        }
    }
    
    /// Marks lyrics as currently loading.
    public func setLyricsLoading() {
        lyricsStatus = .loading
    }
    
    /// Sets loaded lyrics for a given track, updating the active lyrics if the track is still current.
    public func setLyricsLoaded(_ lyrics: [LyricLine], forKey key: String) {
        lyricsCache[key] = lyrics
        if currentState.trackKey == key {
            currentLyrics = lyrics
            lyricsStatus = .loaded
        }
    }
    
    /// Marks lyrics as not found, caching this state to prevent redundant requests.
    public func setLyricsNotFound(forKey key: String) {
        lyricsCache[key] = []
        if currentState.trackKey == key {
            currentLyrics = []
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
