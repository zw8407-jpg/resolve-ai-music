import Foundation
import Testing
@testable import ResolveAIMusic

struct LiveResolveTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["RESOLVE_LIVE_SMOKE"] == "1"))
    func bridgeAndVersionRotation() throws {
        let bridge = ResolveBridge()
        let original = try bridge.snapshot()
        _ = try bridge.call("get_whats_new", arguments: ["since": "21.0.4"])
        let name = "AI Music QA " + UUID().uuidString.prefix(8)
        let nameJSON = String(decoding: try JSONEncoder().encode(name), as: UTF8.self)
        let setup = "t=project.GetMediaPool().CreateEmptyTimeline(\(nameJSON))\nassert t\nassert project.SetCurrentTimeline(t)\nresult={'ok':True}"
        _ = try bridge.call("run_script", arguments: ["script": setup])
        defer {
            let literal = String(decoding: (try? JSONEncoder().encode(original.timelineId)) ?? Data(), as: UTF8.self)
            let restore = "matches=[project.GetTimelineByIndex(i) for i in range(1,project.GetTimelineCount()+1) if project.GetTimelineByIndex(i).GetUniqueId()==\(literal)]\nresult={'restored':project.SetCurrentTimeline(matches[0]) if matches else False}"
            _ = try? bridge.call("run_script", arguments: ["script": restore])
        }
        var session = try bridge.snapshot()
        let input = FileManager.default.temporaryDirectory.appendingPathComponent("resolve-ai-music-live-\(UUID().uuidString).wav")
        let generator = Process()
        generator.executableURL = URL(fileURLWithPath: try AudioProcessor.executable("ffmpeg"))
        generator.arguments = ["-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i",
                               "sine=frequency=440:duration=20", "-ar", "48000", "-ac", "2", "-y", input.path]
        try generator.run()
        generator.waitUntilExit()
        #expect(generator.terminationStatus == 0)
        defer { try? FileManager.default.removeItem(at: input) }
        #expect(FileManager.default.fileExists(atPath: input.path))
        let range = TimeRange(start: session.startFrame, frames: Int((session.frameRate * 20).rounded()), frameRate: session.frameRate, fromMarks: false)
        for action in ["insert", "insert", "swap"] {
            let payload: [String: Any] = ["action": action, "session": try JSONSerialization.jsonObject(with: JSONEncoder().encode(session)),
                "range": try JSONSerialization.jsonObject(with: JSONEncoder().encode(range)), "pair": 3,
                "path": input.path, "operationId": UUID().uuidString]
            let result = try bridge.execute(payload)
            #expect(result["ok"] as? Bool == true)
            session = try bridge.snapshot()
            #expect(session.tracks.first(where: { $0.index == 3 })?.clips.count == 1)
        }
        #expect(session.tracks.first(where: { $0.index == 4 })?.clips.count == 1)
        let previousMain = session.tracks.first(where: { $0.index == 3 })?.clips.first?.id
        let alternatePayload: [String: Any] = ["action": "insert", "targetRole": "alternate",
            "session": try JSONSerialization.jsonObject(with: JSONEncoder().encode(session)),
            "range": try JSONSerialization.jsonObject(with: JSONEncoder().encode(range)), "pair": 3,
            "path": input.path, "operationId": UUID().uuidString]
        _ = try bridge.execute(alternatePayload)
        session = try bridge.snapshot()
        #expect(session.tracks.first(where: { $0.index == 3 })?.clips.first?.id == previousMain)
        #expect(session.tracks.first(where: { $0.index == 4 })?.clips.count == 1)
        print("Live Resolve QA timeline retained: \(name)")
    }
}
