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
