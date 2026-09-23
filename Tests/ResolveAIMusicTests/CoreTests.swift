import Testing
import Foundation
@testable import ResolveAIMusic

struct CoreTests {
    func session(marks: [String: [String: Int]] = [:], tracks: [TrackInfo] = []) -> ResolveSession {
        ResolveSession(projectId: "p", projectName: "Test", timelineId: "t", timelineName: "Timeline",
                       frameRate: 24, startFrame: 86400, timecode: "01:00:11:07", marks: marks, tracks: tracks)
    }
    @Test func testInOutIsRelativeAndInclusive() throws {
        let range = try session(marks: ["audio": ["in": 271, "out": 750]]).range(seconds: 10)
        #expect(range.start == 86671)
        #expect(range.frames == 480)
        #expect(range.duration == 20)
    }
    @Test func testNoMarksUsesPlayhead() throws {
        let range = try session().range(seconds: 20)
        #expect(range.start == 86671)
        #expect(!range.fromMarks)
    }
    @Test func testVideoMarksAndPartialAudio() throws {
        let range = try session(marks: ["audio": ["in": 99], "video": ["in": 0, "out": 23]]).range(seconds: 20)
        #expect(range.frames == 24)
    }
    @Test func testDropFrame() throws {
        #expect(try ResolveSession.frames("01:00:00;00", fps: 29.97) == 107892)
        #expect(try ResolveSession.frames("01:00:00;00", fps: 59.94) == 215784)
        let range = TimeRange(start: 107892, frames: 60, frameRate: 29.97, fromMarks: false)
        #expect(range.timecode(at: 107892, drop: true) == "01:00:00;00")
        #expect(throws: (any Error).self) { try ResolveSession.frames("bad", fps: 24) }
    }
    @Test func testRejectInvalidDuration() {
        #expect(throws: (any Error).self) { try session().range(seconds: .nan) }
        #expect(throws: (any Error).self) { try session().range(seconds: -1) }
    }
    @Test func testPairSkipsForeignAndLockedTracks() {
        let clip = ClipInfo(id: "x", name: "dialogue", start: 0, end: 10, managed: false, path: "")
        let tracks = [TrackInfo(index: 3, name: "Voice", locked: false, clips: [clip]),
                      TrackInfo(index: 4, name: "", locked: true, clips: [])]
        #expect(session(tracks: tracks).suggestedPair() == 5)
    }
    @Test func testBillingError() {
        let data = Data(#"{"error":{"code":"401007"}}"#.utf8)
        #expect(TokenHubMusicClient.responseError(data, status: 402)!.message.contains("后付费"))
    }
    @Test func testOffsetAndBoundary() throws {
        #expect(try session().range(seconds: 20, offset: -10).start == 86431)
        #expect(try session().range(seconds: 20, offset: 10).start == 86911)
        #expect(throws: (any Error).self) { try session(marks: ["audio": ["in": 0, "out": 479]]).range(seconds: 20, offset: -10) }
        let moved = try session(marks: ["audio": ["in": 271, "out": 750]]).range(seconds: 10, offset: 10)
        #expect(moved.start == 86911)
        #expect(moved.frames == 480)
    }
    @Test func testTenPresetsAndOldRequestCompatibility() throws {
        #expect(Presets.names.count == 10)
        #expect(Presets.names.allSatisfy { Presets.descriptions[$0] != nil })
        let json = #"{"preset":"test","prompt":"test","targetTrackPair":3,"timeRange":{"start":86400,"frames":480,"frameRate":24,"fromMarks":false}}"#
        let request = try JSONDecoder().decode(GenerationRequest.self, from: Data(json.utf8))
        #expect(request.targetRole == nil)
    }
    @Test func testSixInterfaceLanguagesAndChineseDefaultFallback() {
        #expect(AppLanguage.allCases.count == 6)
        #expect(AppLanguage.simplifiedChinese.text("设置") == "设置")
        #expect(AppLanguage.english.text("设置") == "Settings")
        #expect(AppLanguage.japanese.text("生成并放入时间线") == "生成してタイムラインへ")
        #expect(AppLanguage.spanish.text("界面语言") == "Idioma de la interfaz")
    }
}
