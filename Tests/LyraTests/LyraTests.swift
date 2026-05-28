import Testing
import Foundation
@testable import Lyra

@Suite struct LyraTests {
    
    @Test func testMusicTrackKey() {
        let track = MusicTrack(title: "Bohemian Rhapsody", artist: "Queen", album: "A Night at the Opera", duration: 355.0)
        #expect(track.trackKey == "Queen - Bohemian Rhapsody")
        
        let emptyTrack = MusicTrack(title: "", artist: "", album: "", duration: 0.0)
        #expect(emptyTrack.trackKey == "")
    }
    
    @Test func testParseSyncedLyrics() {
        let client = LyricsClient()
        let rawContent = """
        [00:05.12] First line of song
        [00:10.00] Second line of song
        [00:15.50] Third line
        """
        
        let parsed = client.parseLyrics(rawContent)
        #expect(parsed.count == 3)
        #expect(parsed[0].timestamp == 5.12)
        #expect(parsed[0].text == "First line of song")
        #expect(parsed[1].timestamp == 10.0)
        #expect(parsed[1].text == "Second line of song")
        #expect(parsed[2].timestamp == 15.5)
        #expect(parsed[2].text == "Third line")
    }
    
    @Test func testParsePlainLyrics() {
        let client = LyricsClient()
        let rawContent = """
        First line
        Second line
        """
        
        let parsed = client.parseLyrics(rawContent)
        // One disclaimer line + two lyrics lines
        #expect(parsed.count == 3)
        #expect(parsed[0].timestamp == 0.0)
        #expect(parsed[0].text == "[Synced lyrics not available. Displaying plain text]")
        #expect(parsed[1].timestamp == 4.0)
        #expect(parsed[1].text == "First line")
        #expect(parsed[2].timestamp == 8.0)
        #expect(parsed[2].text == "Second line")
    }
    
    @Test func testIsVersionNewer() {
        let checker = UpdateChecker(currentVersion: "1.0.0", repo: "Dai-Ski/LYRA")
        
        // Remote is newer
        #expect(checker.isVersionNewer(remote: "1.0.1", current: "1.0.0") == true)
        #expect(checker.isVersionNewer(remote: "1.1.0", current: "1.0.0") == true)
        #expect(checker.isVersionNewer(remote: "2.0.0", current: "1.0.0") == true)
        
        // Remote is older or equal
        #expect(checker.isVersionNewer(remote: "1.0.0", current: "1.0.0") == false)
        #expect(checker.isVersionNewer(remote: "0.9.9", current: "1.0.0") == false)
        
        // Handles version component lengths gracefully
        #expect(checker.isVersionNewer(remote: "1.0", current: "1.0.0") == false)
        #expect(checker.isVersionNewer(remote: "1.0.0.1", current: "1.0.0") == true)
    }
    
    @Test func testRomanization() throws {
        let client = LyricsClient()
        
        #expect(client.romanize("こんにちは") == "kon'nichiha")
        #expect(client.romanize("안녕하세요") == "annyeonghaseyo")
        #expect(client.romanize("你好") == "ni hao")
        #expect(client.romanize("Beautiful Day") == "Beautiful Day")
    }
}
