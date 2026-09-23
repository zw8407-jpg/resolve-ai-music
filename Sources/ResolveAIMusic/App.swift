import SwiftUI
import AppKit
import ApplicationServices

enum AppTheme {
    static let brand = Color(red: 109 / 255, green: 59 / 255, blue: 1)
    static let brandHover = Color(red: 91 / 255, green: 46 / 255, blue: 230 / 255)
    static let brandSoft = Color(red: 238 / 255, green: 233 / 255, blue: 1)
    static let canvas = Color(red: 245 / 255, green: 244 / 255, blue: 248 / 255)
    static let surface = Color.white.opacity(0.88)
    static let field = Color(red: 248 / 255, green: 247 / 255, blue: 250 / 255)
    static let divider = Color(red: 222 / 255, green: 218 / 255, blue: 231 / 255)
    static let mint = Color(red: 81 / 255, green: 244 / 255, blue: 215 / 255)
    static let pink = Color(red: 1, green: 156 / 255, blue: 226 / 255)
    static let yellow = Color(red: 1, green: 212 / 255, blue: 94 / 255)
    static let alternate = Color(red: 91 / 255, green: 140 / 255, blue: 1)
    static let success = Color(red: 52 / 255, green: 199 / 255, blue: 123 / 255)
    static let warning = Color(red: 240 / 255, green: 161 / 255, blue: 58 / 255)
    static let error = Color(red: 230 / 255, green: 82 / 255, blue: 99 / 255)
    static let teal = Color(red: 25 / 255, green: 157 / 255, blue: 137 / 255)
    static let ocean = Color(red: 51 / 255, green: 116 / 255, blue: 224 / 255)
    static let rose = Color(red: 210 / 255, green: 72 / 255, blue: 145 / 255)
}

private struct ColoredChoiceButton: View {
    let title: String
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .foregroundStyle(selected ? Color.white : color)
                .background(selected ? color : color.opacity(0.13), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "已选择" : "未选择")
    }
}

private struct ComposerControlLabel: View {
    let title: String
    var systemImage: String?
    var selected = false

    var body: some View {
        HStack(spacing: 7) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title).lineLimit(1).minimumScaleFactor(0.65)
            if systemImage == nil { Image(systemName: "chevron.up.chevron.down").font(.caption2) }
        }
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity, minHeight: 30)
        .foregroundStyle(selected ? Color.white : AppTheme.ocean)
        .background(selected ? AppTheme.ocean : AppTheme.ocean.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.ocean.opacity(selected ? 0 : 0.16), lineWidth: 0.7)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct BrandCardModifier: ViewModifier {
    var fill: Color = AppTheme.surface
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.divider.opacity(0.72), lineWidth: 0.7)
            }
    }
}

private extension View {
    func brandCard(_ fill: Color = AppTheme.surface) -> some View {
        modifier(BrandCardModifier(fill: fill))
    }
}

private struct CueGateShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 100, sy = rect.height / 100
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }
        var path = Path()
        path.move(to: point(48, 22))
        path.addLine(to: point(58, 22))
        path.addLine(to: point(87, 44))
        path.addQuadCurve(to: point(87, 56), control: point(95, 50))
        path.addLine(to: point(58, 78))
        path.addLine(to: point(48, 78))
        path.addLine(to: point(48, 66))
        path.addLine(to: point(54, 66))
        path.addLine(to: point(75, 50))
        path.addLine(to: point(54, 34))
        path.addLine(to: point(48, 34))
        path.closeSubpath()
        return path
    }
}

enum BrandActivityMode {
    case idle, editing, recording, preflight, generating, downloading, inserting, completed, failed

    init(state: GenerationState) {
        switch state {
        case .idle: self = .idle
        case .preflight: self = .preflight
        case .generating: self = .generating
        case .downloading: self = .downloading
        case .inserting: self = .inserting
        case .completed: self = .completed
        case .failed: self = .failed
        }
    }
    var glow: Color {
        switch self {
        case .idle: AppTheme.brand
        case .editing, .inserting: AppTheme.pink
        case .recording: AppTheme.mint
        case .preflight: AppTheme.yellow
        case .generating: AppTheme.brand
        case .downloading: AppTheme.alternate
        case .completed: AppTheme.success
        case .failed: AppTheme.error
        }
    }
    var label: String {
        switch self {
        case .idle: "待机"
        case .editing: "文字输入"
        case .recording: "语音输入"
        case .preflight: "正在预检"
        case .generating: "正在生成"
        case .downloading: "正在下载"
        case .inserting: "正在写入"
        case .completed: "生成完成"
        case .failed: "任务失败"
        }
    }
    var animated: Bool {
        switch self {
        case .idle, .completed: false
        default: true
        }
    }
}

struct BrandMark: View {
    var mode: BrandActivityMode = .idle
    var highlighted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion || !mode.animated)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                ZStack {
                    RoundedRectangle(cornerRadius: side * 0.22, style: .continuous)
                        .fill(AppTheme.brand.gradient)
                    VStack(alignment: .leading, spacing: side * 0.055) {
                        signalBar(color: AppTheme.mint, width: side * 0.16, height: side * 0.055,
                                  level: signalLevel(index: 0, time: time))
                        signalBar(color: AppTheme.pink, width: side * 0.22, height: side * 0.055,
                                  level: signalLevel(index: 1, time: time))
                        signalBar(color: AppTheme.yellow, width: side * 0.13, height: side * 0.055,
                                  level: signalLevel(index: 2, time: time))
                    }
                    .frame(width: side, height: side, alignment: .center)
                    .offset(x: -side * 0.19)
                    CueGateShape().fill(.white).padding(side * 0.10)
                        .shadow(color: mode.glow.opacity(mode == .idle ? 0.16 : 0.7), radius: side * 0.055)
                }
                .frame(width: side, height: side)
                .shadow(color: mode.glow.opacity(highlighted ? 0.72 : (mode == .idle ? 0.16 : 0.42)),
                        radius: highlighted ? side * 0.23 : side * 0.12, y: 2)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(mode.label)
    }
    private func signalLevel(index: Int, time: Double) -> Double {
        guard !reduceMotion else { return mode == .idle ? 0.86 : 1 }
        let pulse = 0.25 + 0.75 * ((sin(time * 6.2) + 1) / 2)
        switch mode {
        case .idle: return 0.86
        case .editing: return index == 1 ? pulse : 0.34
        case .recording: return index == 0 ? pulse : 0.34
        case .preflight: return index == 2 ? pulse : 0.34
        case .generating: return index == Int(time * 5.4) % 3 ? 1 : 0.22
        case .downloading: return index == (2 - Int(time * 4.6) % 3) ? 1 : 0.28
        case .inserting: return index == Int(time * 7.2) % 3 ? 1 : 0.34
        case .completed: return 1
        case .failed: return pulse
        }
    }
    private func signalBar(color: Color, width: CGFloat, height: CGFloat, level: Double) -> some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: height)
            .opacity(level)
            .scaleEffect(1 + 0.16 * level, anchor: .leading)
            .shadow(color: color.opacity(0.1 + 0.9 * level), radius: 1 + 5 * level)
    }
}

enum MenuBarIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { bounds in
            NSColor.labelColor.setFill()
            for rect in [NSRect(x: 1.5, y: 12.5, width: 4, height: 2),
                         NSRect(x: 1.5, y: 8, width: 5.5, height: 2),
                         NSRect(x: 1.5, y: 3.5, width: 3.2, height: 2)] {
                NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1).fill()
            }
            let gate = NSBezierPath()
            gate.move(to: NSPoint(x: 8.5, y: 15.5))
            gate.line(to: NSPoint(x: 11, y: 15.5))
            gate.line(to: NSPoint(x: 17, y: 10.2))
            gate.curve(to: NSPoint(x: 17, y: 7.8), controlPoint1: NSPoint(x: 18.2, y: 9.6), controlPoint2: NSPoint(x: 18.2, y: 8.4))
            gate.line(to: NSPoint(x: 11, y: 2.5))
            gate.line(to: NSPoint(x: 8.5, y: 2.5))
            gate.line(to: NSPoint(x: 8.5, y: 5.2))
            gate.line(to: NSPoint(x: 10, y: 5.2))
            gate.line(to: NSPoint(x: 14.2, y: 9))
            gate.line(to: NSPoint(x: 10, y: 12.8))
            gate.line(to: NSPoint(x: 8.5, y: 12.8))
            gate.close()
            gate.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Resolve AI Music"
        return image
    }
}

@main struct ResolveMusicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = AppModel()
    var statusItem: NSStatusItem!
    var panel: NSPanel!
    var eventTap: CFMachPort?
    var compactHoverTimer: Timer?
    var lastClick: CFAbsoluteTime = 0
    var lastPoint = CGPoint.zero
    func applicationDidFinishLaunching(_ notification: Notification) {
        // The Electric Violet system is intentionally a light pearl canvas.
        // Pin the app appearance so semantic text never turns white over the
        // fixed white cards when macOS switches to Dark Mode.
        NSApp.appearance = NSAppearance(named: .aqua)
        // Keep a Dock presence so a Finder double-click is visibly acknowledged.
        // The menu-bar workflow remains available after launch.
        NSApp.setActivationPolicy(.regular)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = MenuBarIcon.make()
        statusItem.button?.toolTip = "Resolve AI Music · 点击打开"
        statusItem.button?.target = self; statusItem.button?.action = #selector(toggle)
        let initialSize = model.compact ? NSSize(width: 210, height: 76) : NSSize(width: 480, height: 700)
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: initialSize),
                        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        panel.delegate = self
        panel.appearance = NSAppearance(named: .aqua)
        panel.title = "Resolve AI Music"
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true; panel.level = .floating
        panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        if let green = panel.standardWindowButton(.zoomButton) {
            green.isEnabled = true; green.target = self; green.action = #selector(toggleCompact)
            green.toolTip = "切换迷你控制窗"
            green.setAccessibilityLabel("切换迷你控制窗")
        }
        panel.contentView = NSHostingView(rootView: MusicPanel(model: model,
            installGesture: { [weak self] in self?.installGesture(prompt: true) },
            toggleCompact: { [weak self] in self?.toggleCompact() },
            setCompactHover: { [weak self] hovered in self?.setCompactHover(hovered) }))
        applyCompactAppearance(animated: false)
        installGesture(prompt: false)
        show()
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.terminate(nil)
        return false
    }
    func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        toggleCompact()
        return false
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        show()
        return true
    }
    @objc func toggle() {
        if panel.isMiniaturized { panel.deminiaturize(nil); show() }
        else if panel.isVisible { panel.orderOut(nil) } else { show() }
    }
    @objc func toggleCompact() {
        guard panel.attachedSheet == nil else { return }
        let top = panel.frame.maxY
        model.compact.toggle()
        configurePanelStyle(compact: model.compact)
        let size = NSSize(width: model.compact ? 210 : 480, height: model.compact ? 76 : 700)
        var frame = panel.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        frame.origin = NSPoint(x: panel.frame.minX, y: top - frame.height)
        if let visible = panel.screen?.visibleFrame {
            frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
            frame.origin.y = max(frame.minY, visible.minY)
        }
        panel.setFrame(frame, display: true, animate: true)
        applyCompactAppearance(animated: true)
    }
    private func configurePanelStyle(compact: Bool) {
        panel.styleMask = compact
            ? [.borderless]
            : [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        panel.isMovableByWindowBackground = true
    }
    func setCompactHover(_ hovered: Bool) {
        guard model.compact, model.compactHovered != hovered else { return }
        model.compactHovered = hovered
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = hovered ? 1 : 0.42
        }
    }
    private func pollCompactHover() {
        guard model.compact, panel.isVisible else { return }
        setCompactHover(panel.frame.contains(NSEvent.mouseLocation))
    }
    private func startCompactHoverMonitoring() {
        compactHoverTimer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.pollCompactHover() }
        }
        compactHoverTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    private func applyCompactAppearance(animated: Bool) {
        let compact = model.compact
        panel.titleVisibility = compact ? .hidden : .visible
        panel.hasShadow = true
        for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(type)?.isHidden = compact
        }
        let update = { self.panel.alphaValue = compact ? 0.42 : 1 }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self.panel.animator().alphaValue = compact ? 0.42 : 1
            }
        } else {
            update()
        }
        if compact {
            model.compactHovered = false
            startCompactHoverMonitoring()
        } else {
            compactHoverTimer?.invalidate()
            compactHoverTimer = nil
            model.compactHovered = false
        }
    }
    func show() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            let size = panel.frame.size
            let x = min(max(mouse.x - size.width / 2, frame.minX), frame.maxX - size.width)
            let y = min(max(mouse.y - size.height, frame.minY), frame.maxY - size.height)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        model.refresh()
    }
    func installGesture(prompt: Bool) {
        guard eventTap == nil else { return }
        if prompt { _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary) }
        guard AXIsProcessTrusted() else { return }
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let owner = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = owner.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard type == .otherMouseDown, event.getIntegerValueField(.mouseEventButtonNumber) == 2,
                  NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.blackmagic-design.DaVinciResolve" else {
                owner.lastClick = 0; return Unmanaged.passUnretained(event)
            }
            let now = CFAbsoluteTimeGetCurrent(), point = event.location
            if now - owner.lastClick <= NSEvent.doubleClickInterval && hypot(point.x - owner.lastPoint.x, point.y - owner.lastPoint.y) < 8 {
                owner.lastClick = 0; DispatchQueue.main.async { owner.show() }
            } else { owner.lastClick = now; owner.lastPoint = point }
            return Unmanaged.passUnretained(event)
        }
        eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                                    eventsOfInterest: CGEventMask(1 << CGEventType.otherMouseDown.rawValue),
                                    callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let tap = eventTap {
            CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0), .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        } else { model.message = "中键监听未启用，请检查辅助功能 / 输入监控权限。菜单栏仍可使用。" }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.busy else { model.savePreferences(); return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "任务正在进行"
        alert.informativeText = "退出会中断本地等待，云端请求可能仍计费。"
        alert.addButton(withTitle: "继续等待"); alert.addButton(withTitle: "退出")
        return alert.runModal() == .alertFirstButtonReturn ? .terminateCancel : .terminateNow
    }
}

struct ActivityOrb: View {
    var mode: BrandActivityMode
    var highlighted = false
    var body: some View {
        BrandMark(mode: mode, highlighted: highlighted)
            .frame(width: 50, height: 50)
            .accessibilityLabel(mode.label)
    }
}

struct MusicPanel: View {
    @ObservedObject var model: AppModel
    @StateObject private var voice = VoiceInput()
    @State private var voiceStarting = false
    @State private var showPresetMenu = false
    @FocusState private var editorFocused: Bool
    var installGesture: () -> Void
    var toggleCompact: () -> Void
    var setCompactHover: (Bool) -> Void
    private var locked: Bool { model.busy || voice.recording || voiceStarting }
    private var canGenerate: Bool { !locked && model.hasKey && model.range != nil }
    private var brandMode: BrandActivityMode {
        if voice.recording { return .recording }
        if editorFocused { return .editing }
        return BrandActivityMode(state: model.state)
    }
    private var compactStatus: String {
        if voice.recording { return "正在聆听" }
        switch model.state {
        case .idle: return "为这一刻配乐。"
        case .preflight: return "正在预检"
        case .generating: return "正在生成"
        case .downloading: return "正在下载"
        case .inserting: return "正在写入"
        case .completed: return "已完成"
        case .failed: return "需要处理"
        }
    }
    var body: some View {
        Group {
            if model.compact { mini }
            else {
                VStack(alignment: .leading, spacing: 8) {
                    header
                    durationCard
                    composer
                    generation
                    placement
                }.padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 12)
            }
        }
        .frame(width: model.compact ? 210 : 480, height: model.compact ? 76 : 700)
        .background {
            ZStack {
                Rectangle().fill(.regularMaterial)
                LinearGradient(colors: [AppTheme.canvas.opacity(0.94), AppTheme.brand.opacity(0.045)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }.ignoresSafeArea()
        }
        .preferredColorScheme(.light)
        .environment(\.locale, Locale(identifier: model.language.localeIdentifier))
        .tint(AppTheme.brand)
        .sheet(isPresented: $model.showSettings) { settings }
        .sheet(isPresented: $model.showHistory) { history }
        .alert(model.text("选择空闲音轨"), isPresented: $model.needsTrackConfirmation) {
            Button("\(model.text("使用")) A\(model.pair) / A\(model.pair + 1)") { model.confirmTracks() }
            Button(model.text("取消"), role: .cancel) { }
        } message: { Text(model.text("A3/A4 不可用，或当前工作区位于其他轨道。将使用新的连续空轨。")) + Text(" A\(model.pair) / A\(model.pair + 1)") }
        .onDisappear { voice.stop() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in voice.stop() }
    }
    private var header: some View {
        HStack(spacing: 10) {
            Button(action: toggleCompact) {
                ActivityOrb(mode: brandMode)
                    .scaleEffect(0.84).frame(width: 42, height: 42)
            }.buttonStyle(.plain).help(model.text("切换迷你控制窗")).accessibilityLabel(model.text("切换迷你控制窗"))
            VStack(alignment: .leading, spacing: 3) {
                Text(model.text("为这一刻配乐")).font(.headline)
                Text(voice.recording ? model.text("正在聆听 · 再次点击麦克风结束") : (editorFocused ? model.text("文字输入") : "RESOLVE AI MUSIC"))
                    .font(.system(size: 10, weight: .medium)).tracking(voice.recording || editorFocused ? 0 : 1.8).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(model.session == nil ? AppTheme.warning : AppTheme.success).frame(width: 6, height: 6)
                Text(model.text(model.session == nil ? "未连接达芬奇" : "已连接达芬奇")).font(.caption2).foregroundStyle(.secondary)
            }
            Button { model.showSettings = true } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 16)) }
                .buttonStyle(.plain).help(model.text("设置")).accessibilityLabel(model.text("设置"))
        }
    }
    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.text("音乐时长")).font(.subheadline.weight(.medium))
                Spacer()
                Text(model.text(model.hasMarks ? "跟随 In-Out" : "自定义")).font(.caption).foregroundStyle(.secondary)
                Text(String(format: "%.1f %@", model.range?.duration ?? model.seconds, model.text("秒")))
                    .font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(AppTheme.brand)
            }
            HStack(spacing: 8) {
                ForEach([5.0, 10.0, 20.0], id: \.self) { seconds in
                    Button { model.seconds = seconds } label: {
                        Text("\(Int(seconds)) \(model.text("秒"))").font(.subheadline.weight(.medium)).frame(maxWidth: .infinity).padding(.vertical, 7)
                            .background(model.seconds == seconds ? AppTheme.brandSoft : AppTheme.field, in: Capsule())
                            .foregroundStyle(model.seconds == seconds ? AppTheme.brand : .primary)
                    }.buttonStyle(.plain)
                }
            }.disabled(locked || model.hasMarks)
            HStack {
                Text("1s").font(.caption2).foregroundStyle(.secondary)
                Slider(value: $model.seconds, in: 1...180, step: 1).tint(AppTheme.brand).accessibilityLabel(model.text("音乐时长滑杆"))
                Text("180s").font(.caption2).foregroundStyle(.secondary)
            }.disabled(locked || model.hasMarks)
        }.brandCard()
    }
    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(model.text("风格选择")).font(.subheadline).frame(width: 64, alignment: .leading)
                HStack(spacing: 6) {
                    Button {
                        showPresetMenu.toggle()
                    } label: {
                        ComposerControlLabel(title: model.text(model.preset), selected: true)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .disabled(locked)
                    .popover(isPresented: $showPresetMenu, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Presets.names, id: \.self) { name in
                                Button {
                                    model.preset = name
                                    model.prompt = Presets.descriptions[name] ?? ""
                                    showPresetMenu = false
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(model.text(name))
                                        Spacer(minLength: 16)
                                        if model.preset == name {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(AppTheme.ocean)
                                        }
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(Color.primary)
                                    .frame(width: 180, alignment: .leading)
                                    .frame(minHeight: 26)
                                    .padding(.horizontal, 8)
                                    .background(model.preset == name ? AppTheme.ocean.opacity(0.1) : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(8)
                        .preferredColorScheme(.light)
                    }
                    Button {
                        model.prompt = Presets.randomDescription(for: model.preset, excluding: model.prompt)
                    } label: {
                        ComposerControlLabel(title: model.text("随机风格"), systemImage: "shuffle")
                    }
                    .buttonStyle(.plain).frame(maxWidth: .infinity).disabled(locked)
                    .help(model.text("换一版描述 · 本地随机，无需联网")).accessibilityLabel(model.text("换一版音乐描述"))
                }
            }
            HStack(spacing: 8) {
                Text(model.text("输入方式")).font(.subheadline).frame(width: 64, alignment: .leading)
                HStack(spacing: 6) {
                    Button {
                        model.inputMode = "description"
                    } label: {
                        ComposerControlLabel(title: model.text("音乐描述"), systemImage: "waveform", selected: model.inputMode == "description")
                    }
                    .buttonStyle(.plain).frame(maxWidth: .infinity)
                    Button {
                        model.inputMode = "manuscript"
                    } label: {
                        ComposerControlLabel(title: model.text("文稿配乐"), systemImage: "doc.text", selected: model.inputMode == "manuscript")
                    }
                    .buttonStyle(.plain).frame(maxWidth: .infinity)
                }.disabled(locked)
            }
            ZStack(alignment: .topLeading) {
                if model.inputMode == "manuscript" && model.manuscript.isEmpty {
                    Text(model.text("粘贴解说词、故事梗概或分镜，分析后转成配乐描述…")).foregroundStyle(.tertiary).padding(13).allowsHitTesting(false)
                }
                TextEditor(text: model.inputMode == "manuscript" ? $model.manuscript : $model.prompt)
                    .font(.body).scrollContentBackground(.hidden).padding(8).frame(height: 76).focused($editorFocused).disabled(locked)
            }.background(AppTheme.field, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.divider.opacity(0.8), lineWidth: 0.7) }
            HStack {
                Button(action: toggleVoice) { Label(model.text(voice.recording ? "结束输入" : "语音输入"), systemImage: voice.recording ? "stop.circle.fill" : "mic") }
                    .foregroundStyle(voice.recording ? AppTheme.success : AppTheme.brand).disabled(model.busy || voiceStarting)
                Spacer()
                Button { model.analyze() } label: { Label(model.text(model.composing ? "分析中…" : (model.inputMode == "manuscript" ? "分析文稿" : "优化描述")), systemImage: "sparkles") }.disabled(locked)
            }.buttonStyle(.borderless).font(.caption)
            if model.inputMode == "manuscript" {
                Text(model.text("配乐描述 · 可编辑")).font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $model.prompt).font(.callout).scrollContentBackground(.hidden).padding(8)
                    .frame(height: 70).background(AppTheme.brandSoft.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous)).disabled(locked)
            }
            Text(model.text("文字分析会发送至 TokenHub LLM，并按模型用量计费。")).font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }
    private var generation: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(model.displayMessage).font(.caption).foregroundStyle(model.state == .failed ? AppTheme.error : .secondary).textSelection(.enabled)
                Spacer(minLength: 4)
                Button { model.showHistory = true } label: { Label(model.text("历史与恢复"), systemImage: "clock.arrow.circlepath") }
                    .buttonStyle(.borderless).font(.caption).fixedSize()
            }
            Button { model.prepare() } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text(model.text(model.busy ? "正在处理…" : "生成并放入时间线"))
                    Spacer()
                    Text(model.text("1 首")).font(.caption)
                }
                .fontWeight(.semibold)
                .foregroundStyle(canGenerate ? Color.white : Color.secondary)
                .padding(.horizontal, 13).padding(.vertical, 11)
                .background(canGenerate ? AppTheme.brand : AppTheme.divider.opacity(0.72),
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }.buttonStyle(.plain).disabled(!canGenerate)
            Text(model.text("音乐按首计费。生成后裁切匹配选区，备选默认静音。")).font(.system(size: 10)).foregroundStyle(.tertiary)
            if model.pendingFile != nil || model.state == .failed {
                HStack {
                    Button(model.text("恢复下载")) { model.recoverDownload() }
                    if model.pendingFile != nil { Button(model.text("插入已下载音频")) { model.prepare(reuse: true) } }
                }.font(.caption).disabled(locked)
            }
        }
    }
    private var placement: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(model.session == nil ? AppTheme.warning : AppTheme.success).frame(width: 7, height: 7)
                Text(model.session?.timelineName ?? model.text("未连接时间线")).font(.subheadline.weight(.medium)).lineLimit(1)
                Spacer()
                Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).disabled(locked).help(model.text("读取最新时间线"))
            }
            Text(model.session.map { "\($0.projectName) · \(String(format: "%.3g", $0.frameRate)) fps" } ?? model.text("请打开 Resolve 项目"))
                .font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Text(model.text("目标轨道")).font(.subheadline).frame(width: 64, alignment: .leading)
                HStack(spacing: 6) {
                    ColoredChoiceButton(title: "A\(model.pair) · \(model.text("主版本"))", color: AppTheme.teal, selected: model.targetRole == "main") {
                        model.targetRole = "main"
                    }
                    ColoredChoiceButton(title: "A\(model.pair + 1) · \(model.text("备选"))", color: AppTheme.ocean, selected: model.targetRole == "alternate") {
                        model.targetRole = "alternate"
                    }
                }.disabled(locked)
            }
            HStack(spacing: 8) {
                Text(model.text("放置位置")).font(.subheadline).frame(width: 64, alignment: .leading)
                HStack(spacing: 6) {
                    ColoredChoiceButton(title: model.text("前 10 秒"), color: AppTheme.warning, selected: model.placementOffset == -10) {
                        model.placementOffset = -10
                    }
                    ColoredChoiceButton(title: model.text(model.hasMarks ? "In-Out 起点" : "当前点"), color: AppTheme.teal, selected: model.placementOffset == 0) {
                        model.placementOffset = 0
                    }
                    ColoredChoiceButton(title: model.text("后 10 秒"), color: AppTheme.ocean, selected: model.placementOffset == 10) {
                        model.placementOffset = 10
                    }
                }.disabled(locked)
            }
            if let range = model.range {
                HStack {
                    Text(range.timecode(at: range.start, drop: model.session?.timecode.contains(";") == true) + " → " + range.timecode(at: range.start + Double(range.frames), drop: model.session?.timecode.contains(";") == true))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                    Spacer()
                    Button(model.text("定位")) { model.locate() }.font(.caption).disabled(locked)
                    Button(model.text("采用备选")) { model.swap() }.font(.caption).disabled(locked || model.clip(true) == nil)
                }
            } else if let error = model.rangeError { Text(error).font(.caption).foregroundStyle(AppTheme.error) }
        }.brandCard()
    }
    private var mini: some View {
        HStack(spacing: 11) {
            ActivityOrb(mode: brandMode, highlighted: model.compactHovered).frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text("AI Music").font(.headline).foregroundStyle(AppTheme.brand)
                Text(model.text(compactStatus)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .contentShape(Rectangle())
        .onHover { hovered in
            setCompactHover(hovered)
        }
        .onTapGesture(count: 2, perform: toggleCompact)
    }
    private var settings: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                BrandMark().frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.text("设置")).font(.title2.bold())
                    Text(model.text("连接、模型与交互权限")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.text("完成")) { model.savePreferences(); model.showSettings = false }.keyboardShortcut(.defaultAction)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(model.text("界面语言"), systemImage: "globe").font(.headline)
                        Picker(model.text("界面语言"), selection: $model.language) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(model.text("选择界面显示语言，修改后立即生效。"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .brandCard()
                    .onChange(of: model.language) { _ in model.savePreferences() }
                    VStack(alignment: .leading, spacing: 10) {
                        Label(model.text(model.hasKey ? "TokenHub 密钥已保存" : "连接 TokenHub"), systemImage: "key.fill")
                            .font(.headline).foregroundStyle(model.hasKey ? AppTheme.success : AppTheme.brand)
                        SecureField(model.text("粘贴 TokenHub sk-…"), text: $model.keyInput).textFieldStyle(.roundedBorder)
                        Button(model.text("保存到钥匙串")) { model.saveKey() }.disabled(model.busy)
                    }.brandCard()
                    VStack(alignment: .leading, spacing: 10) {
                        Label(model.text("文稿分析模型"), systemImage: "text.sparkle").font(.headline)
                        TextField(model.text("模型 ID"), text: $model.llmModel).textFieldStyle(.roundedBorder).disabled(model.busy)
                        Text(model.text("填写 TokenHub 的 model 参数值（如 hy3 或 minimax-m3；不要填 minimax）。请单独开通该语言模型的按量服务。"))
                            .font(.caption).foregroundStyle(.secondary)
                    }.brandCard()
                    VStack(alignment: .leading, spacing: 10) {
                        Label(model.text("交互权限"), systemImage: "hand.tap.fill").font(.headline)
                        Button(model.text("启用中键双击 / 重新检查权限"), action: installGesture)
                        Text(model.text("中键双击仅在 Resolve 前台生效。红色退出应用、黄色最小化、绿色或品牌标志切换迷你窗；迷你窗双击恢复完整界面。"))
                            .font(.caption).foregroundStyle(.secondary)
                        Text(model.text("首次在 Resolve 中将主轨设为紫色、备选轨设为蓝色。语音输入使用设备端中文识别，点击麦克风时请求权限。"))
                            .font(.caption).foregroundStyle(.secondary)
                        Link(model.text("TokenHub 在线推理服务"), destination: URL(string: "https://console.cloud.tencent.com/tokenhub/inference")!)
                    }.brandCard()
                    Text(model.displayMessage).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(24).frame(width: 430, height: 560).background(AppTheme.canvas).tint(AppTheme.brand)
    }
    private var history: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                BrandMark().frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.text("历史与恢复")).font(.title2.bold())
                    Text(model.text("保留可执行的恢复入口")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.text("完成")) { model.showHistory = false }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if model.history.isEmpty { Text(model.text("还没有生成记录。")).foregroundStyle(.secondary) }
                    ForEach(model.history.prefix(50)) { entry in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(entry.date, style: .time).font(.caption.monospacedDigit()).foregroundStyle(AppTheme.brand)
                            Text(model.text(entry.message)).fontWeight(.medium)
                            if let backup = entry.backup { Text(model.text("恢复时间线：") + backup).foregroundStyle(.secondary).textSelection(.enabled) }
                            if let path = entry.path {
                                HStack {
                                    Button(model.text("显示文件")) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
                                    Button(model.text("重新采用")) { model.recover(path) }.disabled(locked)
                                }
                            }
                        }.font(.caption).brandCard(AppTheme.surface)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(24).frame(width: 430, height: 480).background(AppTheme.canvas).tint(AppTheme.brand)
    }
    private func toggleVoice() {
        if voice.recording { voice.stop(); return }
        voiceStarting = true
        let manuscript = model.inputMode == "manuscript"
        let original = manuscript ? model.manuscript : model.prompt
        Task {
            await voice.start(onText: { text in
                if manuscript { model.manuscript = original + (original.isEmpty ? "" : "\n") + text }
                else { model.prompt = original + (original.isEmpty ? "" : "\n") + text }
            }, onError: { model.message = $0 })
            voiceStarting = false
        }
    }
}
