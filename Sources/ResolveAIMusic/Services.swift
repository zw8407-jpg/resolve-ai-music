import Foundation
import Security

enum KeychainStore {
    static let service = "io.github.zw8407-jpg.ResolveAIMusic.tokenhub"
    private static let legacyService = "com.local.ResolveAIMusic.tokenhub"
    static func read() -> String? {
        if let value = read(service: service) { return value }
        guard let legacyValue = read(service: legacyService) else { return nil }
        // Preserve existing local installations after adopting the public bundle ID.
        try? save(legacyValue)
        return legacyValue
    }
    private static func read(service: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service, kSecReturnData as String: true]
        var value: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess,
              let data = value as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ value: String) throws {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.hasPrefix("sk-"), key.count >= 16, !key.contains(where: { $0.isWhitespace }) else {
            throw MusicError("请输入完整的 TokenHub sk- 密钥。")
        }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        let attributes: [String: Any] = [kSecValueData as String: Data(key.utf8)]
        let update = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        var insert = query.merging(attributes) { _, new in new }
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = update == errSecItemNotFound ? SecItemAdd(insert as CFDictionary, nil) : update
        guard status == errSecSuccess else { throw MusicError("钥匙串保存失败（\(status)）。") }
    }
}

enum ProcessRunner {
    // All secrets travel in URLSession headers, never command-line arguments or logs.
    static func run(_ path: String, _ arguments: [String], timeout: TimeInterval = 300) throws -> Data {
        let process = Process(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        let timer = DispatchWorkItem { if process.isRunning { process.terminate() } }
        try process.run()
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timer)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timer.cancel()
        guard process.terminationStatus == 0 else { throw MusicError("本地处理失败或超时：\(URL(fileURLWithPath: path).lastPathComponent)") }
        return data
    }
}

struct ResolveBridge {
    static let executable = "/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Applications/ResolveMCP"
    func call(_ name: String, arguments: [String: Any]) throws -> [String: Any] {
        guard FileManager.default.isExecutableFile(atPath: Self.executable) else {
            throw MusicError("未找到 ResolveMCP，请安装 DaVinci Resolve Studio 21.1。")
        }
        let process = Process(), input = Pipe(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: Self.executable)
        process.standardInput = input; process.standardOutput = output; process.standardError = FileHandle.nullDevice
        let timer = DispatchWorkItem { if process.isRunning { process.terminate() } }
        try process.run()
        DispatchQueue.global().asyncAfter(deadline: .now() + 55, execute: timer)
        defer {
            timer.cancel()
            try? input.fileHandleForWriting.close()
            if process.isRunning { process.terminate() }
        }
        func send(_ object: [String: Any]) throws {
            var data = try JSONSerialization.data(withJSONObject: object)
            data.append(10)
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        var buffer = Data()
        func receive(_ id: Int) throws -> [String: Any] {
            while true {
                while let end = buffer.firstIndex(of: 10) {
                    let line = buffer.prefix(upTo: end)
                    buffer.removeSubrange(...end)
                    guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                          object["id"] as? Int == id else { continue }
                    if let error = object["error"] as? [String: Any] { throw MusicError(error["message"] as? String ?? "MCP 错误") }
                    return object["result"] as? [String: Any] ?? [:]
                }
                let data = output.fileHandleForReading.availableData
                guard !data.isEmpty else { throw MusicError("Resolve MCP 未响应；请检查 Resolve 是否打开、脚本权限及日志。") }
                buffer.append(data)
            }
        }
        try send(["jsonrpc": "2.0", "id": 1, "method": "initialize", "params": ["protocolVersion": "2024-11-05", "capabilities": [:], "clientInfo": ["name": "ResolveAIMusic", "version": "1.0"]]])
        _ = try receive(1)
        try send(["jsonrpc": "2.0", "method": "notifications/initialized"])
        try send(["jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": ["name": name, "arguments": arguments]])
        let response = try receive(2)
        let contents = response["content"] as? [[String: Any]] ?? []
        let text = contents.compactMap { $0["text"] as? String }.joined(separator: "\n")
        if response["isError"] as? Bool == true { throw MusicError(text) }
        guard let data = text.data(using: .utf8), let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MusicError("MCP 返回了无法识别的数据。")
        }
        if let error = object["error"] {
            let lines = String(describing: error).split(separator: "\n")
            throw MusicError("Resolve：" + String(lines.last ?? "未知错误"))
        }
        return object["result"] as? [String: Any] ?? object
    }
    func execute(_ request: [String: Any]) throws -> [String: Any] {
        let resource = Bundle.main.resourceURL?
            .appendingPathComponent("ResolveAIMusic_ResolveAIMusic.bundle", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("resolve.py", isDirectory: false)
        guard let resource, FileManager.default.isReadableFile(atPath: resource.path) else {
            throw MusicError("缺少 Resolve 脚本资源。请重新安装应用。")
        }
        let source = try String(contentsOf: resource)
        let json = String(decoding: try JSONSerialization.data(withJSONObject: request), as: UTF8.self)
        // JSON-string literal is compatible with Python for escaped strings; decode via json.loads.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let literal = String(decoding: try encoder.encode(json), as: UTF8.self)
        return try call("run_script", arguments: ["script": "import json\nrequest = json.loads(\(literal))\n" + source, "timeout": 45])
    }
    func snapshot() throws -> ResolveSession {
        let result = try execute(["action": "snapshot"])
        return try JSONDecoder().decode(ResolveSession.self, from: JSONSerialization.data(withJSONObject: result))
    }
}

struct TokenHubMusicClient {
    private let endpoint = URL(string: "https://tokenhub.tencentmaas.com/v1/wand/minimax-music/generation")!
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 300
        return URLSession(configuration: configuration)
    }()
    static func responseError(_ data: Data, status: Int) -> MusicError? {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if let error = json["error"] as? [String: Any] {
            let code = String(describing: error["code"] ?? "")
            if code == "401007" || code == "401008" { return MusicError("MiniMax Music 未启用后付费或免费额度已耗尽。请在 TokenHub 在线推理服务启用该模型。") }
            return MusicError(error["message_zh"] as? String ?? error["message"] as? String ?? "TokenHub 错误 \(code)")
        }
        if !(200...299).contains(status) { return MusicError("TokenHub HTTP \(status)，请检查密钥、余额与服务状态。") }
        if let base = json["base_resp"] as? [String: Any], let code = base["status_code"] as? Int, code != 0 {
            return MusicError(base["status_msg"] as? String ?? "音乐生成失败。")
        }
        return nil
    }
    func generate(key: String, request: GenerationRequest) async throws -> URL {
        var urlRequest = URLRequest(url: endpoint, timeoutInterval: 300)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let prompt = "Instrumental cinematic cue, target duration \(request.duration) seconds. " + request.prompt + " No vocals, no spoken words. Complete musical cadence."
        guard prompt.count <= 2000 else { throw MusicError("描述过长，请缩短至约 1700 字以内。") }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: ["model": "minimax-music-v3.0", "prompt": prompt, "is_instrumental": true, "output_format": "url"])
        let (data, response) = try await Self.session.data(for: urlRequest)
        if let error = Self.responseError(data, status: (response as? HTTPURLResponse)?.statusCode ?? 0) { throw error }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let result = json?["data"] as? [String: Any]
        guard result?["status"] as? Int == 2, let value = result?["audio"] as? String,
              let url = URL(string: value), url.scheme == "https" else { throw MusicError("未收到完成的音频链接；请先检查账单，不自动重复付费请求。") }
        return url
    }
    func download(_ url: URL, to destination: URL) async throws {
        let (temporary, response) = try await Self.session.download(for: URLRequest(url: url, timeoutInterval: 300))
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw MusicError("音频下载失败。") }
        try FileManager.default.moveItem(at: temporary, to: destination)
    }
}

struct AudioProcessor {
    static func executable(_ name: String) throws -> String {
        let choices = [Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/\(name)").path,
                       "/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)"]
        guard let path = choices.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw MusicError("未找到 \(name)。请安装 FFmpeg 后重试。")
        }
        return path
    }
    static func normalize(source: URL, target: URL, range: TimeRange) throws {
        let probe = try ProcessRunner.run(try executable("ffprobe"), ["-v", "error", "-show_entries", "format=duration", "-of", "json", source.path])
        let json = try JSONSerialization.jsonObject(with: probe) as? [String: Any]
        let format = json?["format"] as? [String: Any]
        let length = Double(format?["duration"] as? String ?? "") ?? 0
        guard length + 0.02 >= range.duration else { throw MusicError("模型只返回 \(String(format: "%.1f", length)) 秒，短于选区。已保留源文件，请缩短选区后插入。") }
        let fade = min(0.4, range.duration / 4)
        let filter = "atrim=duration=\(range.duration),asetpts=PTS-STARTPTS,afade=t=in:d=0.15,afade=t=out:st=\(range.duration - fade):d=\(fade)"
        _ = try ProcessRunner.run(try executable("ffmpeg"), ["-nostdin", "-v", "error", "-i", source.path,
            "-af", filter, "-ar", "48000", "-ac", "2", "-c:a", "pcm_s16le", target.path])
        let check = try ProcessRunner.run(try executable("ffprobe"), ["-v", "error", "-show_entries", "format=duration:stream=sample_rate,channels,codec_name", "-of", "json", target.path])
        let info = try JSONSerialization.jsonObject(with: check) as? [String: Any]
        let stream = (info?["streams"] as? [[String: Any]])?.first
        let duration = Double((info?["format"] as? [String: Any])?["duration"] as? String ?? "") ?? 0
        guard abs(duration - range.duration) <= 1.0 / 48000 + 0.000001,
              stream?["sample_rate"] as? String == "48000", stream?["channels"] as? Int == 2,
              stream?["codec_name"] as? String == "pcm_s16le" else { throw MusicError("音频格式或时长校验失败。") }
    }
}

final class WorkspaceStore {
    let root: URL
    init() throws {
        root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ResolveAIMusic")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    func load<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
        guard let data = try? Data(contentsOf: root.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    func save<T: Encodable>(_ value: T, _ name: String) throws {
        try JSONEncoder().encode(value).write(to: root.appendingPathComponent(name), options: .atomic)
    }
    func folder() throws -> URL {
        let url = root.appendingPathComponent("Audio/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
