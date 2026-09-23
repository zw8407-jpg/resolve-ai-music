import SwiftUI
import AVFoundation
import AppKit

@MainActor final class AppModel: ObservableObject {
    @Published var state: GenerationState = .idle
    @Published var message = "打开 Resolve 时间线，开始创作。"
    @Published var session: ResolveSession?
    @Published var seconds = 20.0
    @Published var preset = "雄壮升旗"
    @Published var prompt = Presets.descriptions["雄壮升旗"]!
    @Published var pair = 3
    @Published var hasKey = false
    @Published var keyInput = ""
    @Published var showSettings = false
    @Published var showHistory = false
    @Published var needsTrackConfirmation = false
    @Published var history: [HistoryEntry] = []
    @Published var pendingFile: URL?
    @Published var previewRole: String?
    @Published var isRefreshing = false
    @Published var targetRole = "main"
    @Published var placementOffset = 0.0
    @Published var inputMode = "description"
    @Published var manuscript = ""
    @Published var llmModel = "hy3"
    @Published var composing = false
    @Published var explanation = ""
    @Published var showExplanation = false
    @Published var compact = false
    @Published var compactHovered = false
    @Published var language: AppLanguage = .simplifiedChinese
    private var store: WorkspaceStore?
    private var player: AVAudioPlayer?
    private var versions: [MusicVersion] = []
    private var preparedRequest: GenerationRequest?
    private var preparedSession: ResolveSession?
    private var confirmedPairs: [String: Int] = [:]
    private var pendingPrompt = ""
    private var pendingSource: URL?
    var busy: Bool { [.preflight, .generating, .downloading, .inserting].contains(state) || isRefreshing || composing }
    var range: TimeRange? { try? session?.range(seconds: seconds, offset: placementOffset) }
    var rangeError: String? {
        guard let session else { return nil }
        do { _ = try session.range(seconds: seconds, offset: placementOffset); return nil }
        catch { return error.localizedDescription }
    }
    var hasMarks: Bool { (try? session?.range(seconds: seconds).fromMarks) == true }
    var displayMessage: String {
        let connectedPrefix = "已连接 · "
        if message.hasPrefix(connectedPrefix) {
            return "\(text("已连接")) · \(message.dropFirst(connectedPrefix.count))"
        }
        return text(message)
    }

    init() {
        do {
            let workspace = try WorkspaceStore()
            store = workspace
            history = workspace.load([HistoryEntry].self, "history.json") ?? []
            versions = workspace.load([MusicVersion].self, "versions.json") ?? []
            if let prefs = workspace.load([String: String].self, "preferences.json") {
                prompt = prefs["prompt"] ?? prompt
                preset = prefs["preset"] ?? preset
                language = prefs["language"].flatMap(AppLanguage.init(rawValue:)) ?? .simplifiedChinese
                // `minimax` was an early placeholder, not a TokenHub model ID.
                // Preserve valid custom IDs such as `minimax-m3`, but self-heal it.
                let savedModel = prefs["llmModel"] ?? "hy3"
                llmModel = savedModel == "minimax" ? "hy3" : savedModel
            }
        } catch { message = "无法访问工作目录：\(error.localizedDescription)" }
        // UI snapshots can opt out of Keychain access so visual tests never trigger
        // or alter a user's security authorization. Normal launches always read it.
        hasKey = ProcessInfo.processInfo.environment["RESOLVE_AI_MUSIC_UI_TEST"] == "1" ? false : KeychainStore.read() != nil
    }
    func record(_ text: String, backup: String? = nil, path: String? = nil) {
        history.insert(HistoryEntry(message: text, backup: backup, path: path), at: 0)
        do { try store?.save(history, "history.json") }
        catch { message = "操作完成，但历史保存失败：\(error.localizedDescription)" }
    }
    func saveKey() {
        do { try KeychainStore.save(keyInput); keyInput = ""; hasKey = true; message = "密钥已保存到 macOS 钥匙串。" }
        catch { message = error.localizedDescription }
    }
    func savePreferences() {
        do { try store?.save(["preset": preset, "prompt": prompt, "llmModel": llmModel, "language": language.rawValue], "preferences.json") }
        catch { message = error.localizedDescription }
    }
    func text(_ key: String) -> String { language.text(key) }
    func analyze(explain: Bool = false) {
        guard !busy else { return }
        guard let key = KeychainStore.read() else { message = "请先在设置中保存 TokenHub API Key。"; showSettings = true; return }
        let text = explain ? (Presets.descriptions[preset] ?? preset) : (inputMode == "manuscript" ? manuscript : prompt)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { message = "请先输入文稿或音乐描述。"; return }
        let model = llmModel, style = preset, duration = range?.duration ?? seconds
        composing = true
        message = explain ? "正在解释风格…" : "正在将文字转化为配乐方案…"
        savePreferences()
        Task {
            defer { composing = false }
            do {
                let result = try await ComposerClient().compose(key: key, model: model, text: text, style: style, duration: duration, explain: explain)
                if explain { explanation = result; showExplanation = true }
                else { prompt = result; savePreferences() }
                message = explain ? "风格说明已就绪。" : "配乐描述已生成，可编辑后再生成音乐。"
            } catch { message = error.localizedDescription }
        }
    }
    func refresh() {
        guard !busy else { return }
        isRefreshing = true
        Task {
            defer { isRefreshing = false }
            do {
                let fresh = try await Task.detached { try ResolveBridge().snapshot() }.value
                session = fresh
                pair = fresh.suggestedPair()
                message = "已连接 · \(fresh.timelineName)"
            } catch { session = nil; message = error.localizedDescription }
        }
    }
    func prepare(reuse: Bool = false) {
        guard !busy else { return }
        state = .preflight
        stopPreview()
        Task {
            do {
                guard store != nil else { throw MusicError("工作目录不可用。") }
                if !reuse { guard KeychainStore.read() != nil else { throw MusicError("请先在设置中保存 TokenHub API Key。") } }
                guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw MusicError("请输入音乐描述。") }
                _ = try AudioProcessor.executable("ffmpeg")
                _ = try AudioProcessor.executable("ffprobe")
                let fresh = try await Task.detached { try ResolveBridge().snapshot() }.value
                session = fresh; pair = fresh.suggestedPair()
                let range = try fresh.range(seconds: seconds, offset: placementOffset)
                for track in fresh.tracks where track.index == pair || track.index == pair + 1 {
                    for clip in track.clips where clip.start < range.start + Double(range.frames) && clip.end > range.start {
                        guard abs(clip.start - range.start) < 0.01 && abs(clip.end - clip.start - Double(range.frames)) < 0.01 else {
                            throw MusicError("选区与已有音乐部分重叠。请设置与原片段一致的 In-Out 后重试。")
                        }
                    }
                }
                preparedSession = fresh
                preparedRequest = GenerationRequest(preset: preset, prompt: reuse ? pendingPrompt : prompt, timeRange: range, targetTrackPair: pair, targetRole: targetRole)
                if pair != 3 && confirmedPairs[fresh.timelineId] != pair {
                    needsTrackConfirmation = true
                    state = .idle
                    reuseAfterConfirmation = reuse
                } else { await runPrepared(reuse: reuse) }
            } catch { fail(error) }
        }
    }
    private var reuseAfterConfirmation = false
    func confirmTracks() {
        if let session = preparedSession { confirmedPairs[session.timelineId] = pair }
        needsTrackConfirmation = false
        Task { await runPrepared(reuse: reuseAfterConfirmation) }
    }
    func runPrepared(reuse: Bool) async {
        guard let request = preparedRequest, let session = preparedSession, let store else { return }
        do {
            let file: URL
            if reuse {
                guard let source = pendingSource ?? pendingFile else { throw MusicError("没有待插入音频。") }
                let folder = try store.folder()
                file = folder.appendingPathComponent("music.wav")
                state = .downloading; message = "匹配新的时间范围…"
                try await Task.detached { try AudioProcessor.normalize(source: source, target: file, range: request.timeRange) }.value
            } else {
                guard let key = KeychainStore.read() else { throw MusicError("密钥未配置。") }
                savePreferences()
                let folder = try store.folder()
                try store.save(request, "last-request.json")
                state = .generating; message = "云端创作中…通常需要数分钟。本次只提交一首。"
                record("已提交生成；若超时请核对账单后再生成。")
                let url = try await TokenHubMusicClient().generate(key: key, request: request)
                state = .downloading; message = "正在下载与校验音频…"
                let source = folder.appendingPathComponent("source.mp3")
                // Persist the expiring URL locally to recover a failed download without a second paid call.
                try store.save(["url": url.absoluteString, "folder": folder.path], "pending-download.json")
                try await TokenHubMusicClient().download(url, to: source)
                pendingSource = source; pendingPrompt = request.prompt
                file = folder.appendingPathComponent("music.wav")
                try await Task.detached { try AudioProcessor.normalize(source: source, target: file, range: request.timeRange) }.value
            }
            pendingFile = file
            try store.save(["path": file.path, "source": pendingSource?.path ?? file.path, "prompt": request.prompt], "pending-audio.json")
            state = .inserting; message = "音频已就绪，正在备份并写入时间线…"
            let result = try await mutate(action: "insert", session: session, range: request.timeRange, path: file.path, role: request.targetRole ?? "main")
            versions.append(MusicVersion(role: request.targetRole ?? "main", timelineId: session.timelineId, startFrame: request.timeRange.start,
                                         durationFrames: request.timeRange.frames, localPath: file.path, prompt: request.prompt))
            try store.save(versions, "versions.json")
            let notice = request.targetRole == "alternate" ? "已写入 A\(pair + 1) 备选（静音），主版本保持不变。" : "已写入 A\(pair)，原主版本保留在 A\(pair + 1)（静音）。"
            finish(result, text: notice, path: file.path)
            pendingFile = nil; pendingSource = nil
            try store.save([String: String](), "pending-audio.json")
            try store.save([String: String](), "pending-download.json")
        } catch { fail(error) }
    }
    private func mutate(action: String, session: ResolveSession, range: TimeRange, path: String? = nil, role: String = "main") async throws -> [String: Any] {
        let snapshot = try JSONSerialization.jsonObject(with: JSONEncoder().encode(session))
        let rangeJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(range))
        var payload: [String: Any] = ["action": action, "session": snapshot, "range": rangeJSON,
                                      "pair": pair, "operationId": UUID().uuidString, "targetRole": role]
        if let path { payload["path"] = path }
        return try await Task.detached { try ResolveBridge().execute(payload) }.value
    }
    func swap() {
        guard !busy else { return }
        state = .inserting; stopPreview()
        Task {
            do {
                let fresh = try await Task.detached { try ResolveBridge().snapshot() }.value
                pair = fresh.suggestedPair()
                let result = try await mutate(action: "swap", session: fresh, range: fresh.range(seconds: seconds, offset: placementOffset))
                finish(result, text: "主备版本已互换；备选保持静音。")
            } catch { fail(error) }
        }
    }
    func finish(_ result: [String: Any], text: String, path: String? = nil) {
        if let snapshot = result["snapshot"], let data = try? JSONSerialization.data(withJSONObject: snapshot) {
            session = try? JSONDecoder().decode(ResolveSession.self, from: data)
        }
        if let session {
            for index in versions.indices where versions[index].timelineId == session.timelineId {
                let path = versions[index].localPath
                let track = session.tracks.first { $0.clips.contains { $0.path == path } }
                versions[index].role = track?.index == pair ? "main" : (track?.index == pair + 1 ? "alternate" : "history")
            }
            try? store?.save(versions, "versions.json")
        }
        state = .completed; message = text
        record(text, backup: result["backup"] as? String, path: path)
    }
    func fail(_ error: Error) {
        state = .failed
        message = error.localizedDescription
        if (error as? URLError)?.code == .timedOut {
            message = "请求超时，服务端可能仍在生成。请先核对 TokenHub 账单；本应用不会自动重发付费请求。"
        }
        record(message, path: pendingFile?.path ?? pendingSource?.path)
    }
    func clip(_ alternate: Bool) -> ClipInfo? {
        guard let range else { return nil }
        return session?.tracks.first(where: { $0.index == pair + (alternate ? 1 : 0) })?.clips.first {
            $0.managed && abs($0.start - range.start) < 0.01
        }
    }
    func preview(_ alternate: Bool) {
        guard let clip = clip(alternate) else { return }
        do {
            stopPreview()
            player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: clip.path))
            player?.play(); previewRole = alternate ? "备选" : "主版本"
        } catch { message = "试听失败：\(error.localizedDescription)" }
    }
    func stopPreview() { player?.stop(); player = nil; previewRole = nil }
    func locate() {
        guard !busy, let session, let range else { return }
        state = .preflight
        Task {
            defer { state = .idle }
            do {
                let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(session))
                let timecode = range.timecode(at: range.start, drop: session.timecode.contains(";"))
                _ = try await Task.detached { try ResolveBridge().execute(["action": "locate", "session": object, "timecode": timecode]) }.value
                // The playhead is now the shifted origin; do not apply the offset twice.
                if !range.fromMarks { placementOffset = 0 }
                self.session = try await Task.detached { try ResolveBridge().snapshot() }.value
                if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.blackmagic-design.DaVinciResolve" }) {
                    app.activate(options: .activateIgnoringOtherApps)
                }
            } catch { message = error.localizedDescription }
        }
    }
    func recover(_ path: String) {
        pendingFile = URL(fileURLWithPath: path); pendingSource = pendingFile
        pendingPrompt = versions.last(where: { $0.localPath == path })?.prompt ?? prompt
        message = "已选中历史音频；设置目标范围后点击“插入已下载音频”。"
        showHistory = false
    }
    func recoverDownload() {
        guard !busy, let store else { return }
        if let saved = store.load([String: String].self, "pending-audio.json"), let path = saved["path"] {
            recover(path); pendingSource = URL(fileURLWithPath: saved["source"] ?? path)
            pendingPrompt = saved["prompt"] ?? prompt
            return
        }
        guard let saved = store.load([String: String].self, "pending-download.json"), let value = saved["url"],
              let url = URL(string: value), let folder = saved["folder"] else { message = "没有待恢复任务。"; return }
        state = .downloading
        Task {
            do {
                let source = URL(fileURLWithPath: folder).appendingPathComponent("recovered-\(UUID().uuidString).mp3")
                try await TokenHubMusicClient().download(url, to: source)
                pendingSource = source; pendingFile = source
                pendingPrompt = store.load(GenerationRequest.self, "last-request.json")?.prompt ?? prompt
                state = .idle; message = "已恢复下载，请选择范围后插入。"
            } catch { fail(error) }
        }
    }
}
