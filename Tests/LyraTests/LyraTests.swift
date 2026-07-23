import XCTest
@testable import Lyra

final class LyraTests: XCTestCase {
    
    // MARK: - 1. Romanized Mode Persistence Tests
    func testRomanizedModePersistsOnTrackChange() async {
        let actor = AppStateActor()
        
        // Initial state: original mode
        let (_, _, initialMode, _) = await actor.getLyrics()
        XCTAssertEqual(initialMode, .original)
        
        // User selects romanized mode
        await actor.setLyricMode(.romanized)
        let (_, _, selectedMode, _) = await actor.getLyrics()
        XCTAssertEqual(selectedMode, .romanized)
        
        // Load first track with lyrics
        await actor.updatePlayback(
            isMusicRunning: true,
            isPlaying: true,
            title: "Song A",
            artist: "Artist A",
            album: "Album A",
            position: 10.0,
            duration: 200.0
        )
        
        let originalLinesA = [LyricLine(timestamp: 5.0, text: "こんにちは")]
        let romanizedLinesA = [LyricLine(timestamp: 5.0, text: "Konnichiwa")]
        await actor.setLyricsLoaded(original: originalLinesA, romanized: romanizedLinesA, forKey: "Artist A - Song A")
        
        let (lyricsA, _, modeA, _) = await actor.getLyrics()
        XCTAssertEqual(modeA, .romanized)
        XCTAssertEqual(lyricsA.first?.text, "Konnichiwa")
        
        // Track changes to Song B
        await actor.updatePlayback(
            isMusicRunning: true,
            isPlaying: true,
            title: "Song B",
            artist: "Artist B",
            album: "Album B",
            position: 0.0,
            duration: 180.0
        )
        
        let originalLinesB = [LyricLine(timestamp: 2.0, text: "Hello world")]
        let romanizedLinesB = [LyricLine(timestamp: 2.0, text: "Hello world")]
        await actor.setLyricsLoaded(original: originalLinesB, romanized: romanizedLinesB, forKey: "Artist B - Song B")
        
        // Ensure mode is STILL romanized and didn't reset to original
        let (_, _, modeB, _) = await actor.getLyrics()
        XCTAssertEqual(modeB, .romanized, "Lyric mode must persist as romanized across track switches until app is quit.")
    }

    // MARK: - 2. LRC Parser Tests
    func testLRCParserStandardAndSubseconds() {
        let client = LyricsClient()
        let lrcContent = """
        [00:12.34]First line
        [01:05.678]Second line
        [02:10:50]Third line with colon subsecond
        [03:00]Fourth line no subsecond
        """
        
        let lines = client.parseLyrics(lrcContent)
        XCTAssertEqual(lines.count, 4)
        
        XCTAssertEqual(lines[0].timestamp, 12.34, accuracy: 0.001)
        XCTAssertEqual(lines[0].text, "First line")
        
        XCTAssertEqual(lines[1].timestamp, 65.678, accuracy: 0.001)
        XCTAssertEqual(lines[1].text, "Second line")
        
        XCTAssertEqual(lines[2].timestamp, 130.50, accuracy: 0.001)
        XCTAssertEqual(lines[2].text, "Third line with colon subsecond")
        
        XCTAssertEqual(lines[3].timestamp, 180.0, accuracy: 0.001)
        XCTAssertEqual(lines[3].text, "Fourth line no subsecond")
    }

    func testLRCParserMultiTimestampLine() {
        let client = LyricsClient()
        let lrcContent = """
        [00:10.00][01:20.00]Chorus line repeated
        """
        
        let lines = client.parseLyrics(lrcContent)
        XCTAssertEqual(lines.count, 2)
        
        XCTAssertEqual(lines[0].timestamp, 10.0)
        XCTAssertEqual(lines[0].text, "Chorus line repeated")
        
        XCTAssertEqual(lines[1].timestamp, 80.0)
        XCTAssertEqual(lines[1].text, "Chorus line repeated")
    }

    func testLRCParserOffsetAndMetadataStripping() {
        let client = LyricsClient()
        let lrcContent = """
        [ti:Test Title]
        [ar:Test Artist]
        [offset:+1000]
        [00:05.00]Offsetted line
        """
        
        let lines = client.parseLyrics(lrcContent)
        XCTAssertEqual(lines.count, 1)
        
        // 5.0s + 1.0s offset = 6.0s
        XCTAssertEqual(lines[0].timestamp, 6.0, accuracy: 0.001)
        XCTAssertEqual(lines[0].text, "Offsetted line")
    }
    
    func testCleanTitle() {
        let client = LyricsClient()
        XCTAssertEqual(client.cleanTitle("Shape of You (feat. Someone)"), "Shape of You")
        XCTAssertEqual(client.cleanTitle("Hotel California - Remastered 2013"), "Hotel California")
        XCTAssertEqual(client.cleanTitle("Despacito [Official Video]"), "Despacito")
    }
}
