import Foundation

struct MusicError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

struct ClipInfo: Codable, Equatable {
    var id: String
    var name: String
    var start: Double
    var end: Double
    var managed: Bool
    var path: String
}
struct TrackInfo: Codable, Equatable {
    var index: Int
    var name: String
    var locked: Bool
    var clips: [ClipInfo]
}
struct ResolveSession: Codable {
    var projectId: String
    var projectName: String
    var timelineId: String
    var timelineName: String
    var frameRate: Double
    var startFrame: Double
    var timecode: String
    var marks: [String: [String: Int]]
    var tracks: [TrackInfo]

    func range(seconds: Double, offset: Double = 0) throws -> TimeRange {
        guard frameRate > 0, seconds.isFinite, seconds >= 1, seconds <= 180 else {
            throw MusicError("请输入 1–180 秒。")
        }
        let audio = marks["audio"] ?? [:], video = marks["video"] ?? [:]
        let mark = audio["in"] != nil && audio["out"] != nil ? audio : video
        if let begin = mark["in"], let end = mark["out"], end >= begin, begin >= 0 {
            let frames = end - begin + 1
            guard Double(frames) / frameRate <= 180 else { throw MusicError("首版支持最多 180 秒的 In-Out 区间。") }
            let start = startFrame + Double(begin) + (offset * frameRate).rounded()
            guard start >= startFrame else { throw MusicError("偏移后早于时间线起点，请调整定位。") }
            return TimeRange(start: start, frames: frames, frameRate: frameRate, fromMarks: true)
        }
        let start = Double(try Self.frames(timecode, fps: frameRate)) + (offset * frameRate).rounded()
        guard start >= startFrame else { throw MusicError("偏移后早于时间线起点，请调整定位。") }
        return TimeRange(start: start,
                         frames: Int((seconds * frameRate).rounded()), frameRate: frameRate, fromMarks: false)
    }

    static func frames(_ timecode: String, fps: Double) throws -> Int {
        let parts = timecode.replacingOccurrences(of: ";", with: ":").split(separator: ":").compactMap { Int($0) }
        let nominal = Int(fps.rounded())
        guard parts.count == 4, nominal > 0, parts.allSatisfy({ $0 >= 0 }), parts[1] < 60,
              parts[2] < 60, parts[3] < nominal else { throw MusicError("无法解析播放头时间码：\(timecode)") }
        var count = ((parts[0] * 60 + parts[1]) * 60 + parts[2]) * nominal + parts[3]
        if timecode.contains(";") {
            guard abs(fps - 29.97) < 0.01 || abs(fps - 59.94) < 0.01 else { throw MusicError("不支持此丢帧时间码。") }
            let minutes = parts[0] * 60 + parts[1]
            count -= (nominal == 60 ? 4 : 2) * (minutes - minutes / 10)
        }
        return count
    }

    func suggestedPair() -> Int {
        if let main = tracks.first(where: { $0.name == "AI MUSIC · 主版本" }),
           tracks.contains(where: { $0.index == main.index + 1 && $0.name == "AI MUSIC · 备选版本" }),
           pairSafe(main.index) { return main.index }
        let lastIndex = tracks.map(\.index).max() ?? 0
        for index in 3...max(3, lastIndex + 1) where pairSafe(index) { return index }
        return max(3, lastIndex + 1)
    }
    func pairSafe(_ index: Int) -> Bool {
        (index...index + 1).allSatisfy { number in
            guard let track = tracks.first(where: { $0.index == number }) else { return true }
            return !track.locked && track.clips.allSatisfy(\.managed)
        }
    }
}
struct TimeRange: Codable {
    var start: Double
    var frames: Int
    var frameRate: Double
    var fromMarks: Bool
    var duration: Double { Double(frames) / frameRate }
    func timecode(at frame: Double, drop: Bool) -> String {
        let nominal = Int(frameRate.rounded())
        var value = max(0, Int(frame.rounded()))
        if drop && (nominal == 30 || nominal == 60) {
            let dropped = nominal == 60 ? 4 : 2
            let perTenMinutes = nominal * 600 - dropped * 9
            let blocks = value / perTenMinutes, remainder = value % perTenMinutes
            value += dropped * 9 * blocks
            if remainder >= dropped { value += dropped * ((remainder - dropped) / (nominal * 60 - dropped)) }
        }
        return String(format: "%02d:%02d:%02d%@%02d", value / (nominal * 3600), (value / (nominal * 60)) % 60,
                      (value / nominal) % 60, drop ? ";" : ":", value % nominal)
    }
}
enum GenerationState: String { case idle, preflight, generating, downloading, inserting, completed, failed }
struct GenerationRequest: Codable {
    var preset: String
    var prompt: String
    var timeRange: TimeRange
    var targetTrackPair: Int
    var targetRole: String? = nil
    var duration: Double { timeRange.duration }
}
struct MusicVersion: Codable, Identifiable {
    var id = UUID().uuidString
    var role: String
    var timelineId: String
    var startFrame: Double
    var durationFrames: Int
    var localPath: String
    var model = "minimax-music-v3.0"
    var prompt: String
    var createdAt = Date()
}
struct HistoryEntry: Codable, Identifiable {
    var id = UUID().uuidString
    var date = Date()
    var message: String
    var backup: String?
    var path: String?
}
enum Presets {
    static let descriptions = [
        "雄壮升旗": "轻柔钢琴与弦乐开场，清晰上行的英雄主题，军鼓逐步建立节奏，铜管和定音鼓推进至庄严雄壮的高潮，以完整和弦收束。无人声。",
        "温暖叙事": "温暖钢琴、木吉他与细腻弦乐，旋律清晰，情绪逐步推进，留出对白空间，自然收束。无人声。",
        "悬疑张力": "低音弦乐与克制脉冲，逐渐增加节奏与和声张力，电影感，避免尖锐突发声。无人声。",
        "科技律动": "干净电子音色，鲜明节拍，逐层加入旋律与鼓组，现代明亮，完整收尾。无人声。",
        "史诗磅礴": "宽广管弦乐、铜管与大鼓，层层递进的英雄主题，宏大空间与清晰旋律，高潮后完整收束。无人声。",
        "清新自然": "木吉他、轻柔木管和拨弦，明快轻盈的旋律，仿佛清晨自然光，节奏舒展，清爽收尾。无人声。",
        "古风国韵": "古筝、笛子与弦乐融合，东方五声旋律，含蓄起势，逐渐展开，意境悠远，完整收束。无人声。",
        "轻快活力": "明亮钢琴、贝斯与轻快鼓点，富有跳跃感的流行旋律，积极有活力，干净利落的结尾。无人声。",
        "沉静冥想": "柔和环境音色、稀疏钢琴与绵长弦乐，缓慢呼吸般起伏，无突发声，平静自然收束。无人声。",
        "爵士都市": "温暖电钢琴、爵士吉他、低音贝斯与刷奏鼓，松弛律动，优雅城市夜色，清晰主题与自然尾奏。无人声。"
    ]
    static let names = ["雄壮升旗", "温暖叙事", "悬疑张力", "科技律动", "史诗磅礴", "清新自然", "古风国韵", "轻快活力", "沉静冥想", "爵士都市"]

    // Curated alternatives keep the selected style while varying melody and rhythm.
    static let alternatives: [String: [String]] = [
        "雄壮升旗": [
            "独奏圆号轻声引出庄严主题，中低弦乐托底，军鼓以稳定进行曲节奏进入，铜管齐奏将旋律逐级抬升，终止于宽广主和弦。无人声。",
            "木管与竖琴铺开晨光般前奏，弦乐奏出舒展上行旋律，渐入有力定音鼓与小号应答，形成威武而明亮的高潮，长音收束。无人声。"
        ],
        "温暖叙事": [
            "木吉他轻柔分解和弦，大提琴唱出亲切主题，钢琴在句尾回应，刷鼓缓缓带动叙事，旋律从含蓄走向明亮，温柔落定。无人声。",
            "柔和电钢琴先奏稀疏动机，单簧管延伸为流畅旋律，低音贝斯建立舒缓摇摆，弦乐渐次展开，保留对白空间，轻轻收尾。无人声。"
        ],
        "悬疑张力": [
            "断奏大提琴重复短促音型，低频电子脉冲逐渐加密，钢琴高音给出悬而未决的旋律，节奏短暂停顿后重入，克制地结束。无人声。",
            "低音单簧管提出阴影般主题，钟琴零星回应，弦乐震音与不规则打击乐推动调查感，紧张逐步攀升，以低沉尾音收束。无人声。"
        ],
        "科技律动": [
            "清透合成器琶音从稀疏到密集，弹性贝斯与切分电子鼓进入，明亮短主题逐次变化，高潮增加高八度旋律，干净收尾。无人声。",
            "柔和数字音色开场，低频脉冲稳定前行，钢琴动机与未来感音序交替应答，鼓点逐步增强，空间开阔，结尾自然消解。无人声。"
        ],
        "史诗磅礴": [
            "大提琴低声奏出远征主题，圆号扩展旋律，战鼓稳步推进，小提琴快速音型衬托铜管高峰，强弱对比鲜明，壮阔终止。无人声。",
            "竖琴与长笛开启辽阔景象，弦乐缓慢堆叠和声，低鼓带出厚重步伐，小号高声回应主题，气势逐层展开，完整落定。无人声。"
        ],
        "清新自然": [
            "尤克里里轻巧扫弦，口风琴奏出跳跃短句，手摇沙锤带动轻松节奏，木管交织如林间微风，旋律回归主题后明亮收尾。无人声。",
            "尼龙吉他轻声拨奏，长笛吹出舒展旋律，木琴点缀清晨质感，轻拍鼓逐渐进入，温润流动，结尾保留短暂余韵。无人声。"
        ],
        "古风国韵": [
            "箫声从留白中引出悠远主题，古琴泛音回应，琵琶轮指逐步带动节奏，弦乐托起五声旋律，以清淡古筝尾音收束。无人声。",
            "扬琴以清亮音型开场，二胡奏出绵长东方旋律，堂鼓克制推进，笛子在高处应答，情绪从柔和走向开阔，完整回归主音。无人声。"
        ],
        "轻快活力": [
            "拨弦吉他抛出俏皮主题，弹跳贝斯与清脆拍手建立律动，钢琴逐句变化旋律，副段加入明亮铜管，节奏鲜明，利落结尾。无人声。",
            "木琴与电钢琴交替奏出短旋律，轻快鼓组带动前行，切分吉他增加层次，主题在高八度再次出现，积极明朗，自然收束。无人声。"
        ],
        "沉静冥想": [
            "柔和马林巴用稀疏音符形成缓慢呼吸，低音弦乐绵长铺底，钢琴主题轻微变化，音量平稳而有细腻起伏，安静收束。无人声。",
            "温暖合成器长音渐入，竖琴隔句点出简单旋律，低音笛缓缓回应，无明显重拍，留白充足，以柔和和声与短余韵结束。无人声。"
        ],
        "爵士都市": [
            "爵士钢琴奏出蓝调短句，拨奏低音与刷鼓形成轻松摇摆，弱音小号回应旋律，经过短暂和声转折回到主题，温暖收尾。无人声。",
            "电颤琴轻柔开场，爵士吉他以切分和弦衬托，贝斯稳定行走，中段钢琴展开优雅旋律，夜色松弛，简洁终止。无人声。"
        ]
    ]

    static func randomDescription(for style: String, excluding current: String) -> String {
        let choices = ([descriptions[style]].compactMap { $0 } + (alternatives[style] ?? []))
            .filter { $0 != current }
        return choices.randomElement() ?? current
    }
}
