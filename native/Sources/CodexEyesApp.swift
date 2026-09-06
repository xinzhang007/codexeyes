import AppKit
import Darwin
import SwiftUI

private let accent = Color(red: 0.416, green: 0.353, blue: 0.976)
private let ink = Color.white
private let softLine = Color.white.opacity(0.17)
private let subtle = Color.white.opacity(0.70)

@main
struct CodexEyesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let bundleID = Bundle.main.bundleIdentifier ?? "local.codex.eyes"
        let otherInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0 != NSRunningApplication.current }
        if let existing = otherInstances.first {
            existing.activate()
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        createStatusItem()
        createPanel()
    }

    private func createPanel() {
        let size = NSSize(width: 260, height: 285)
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(x: visibleFrame.maxX - size.width - 58, y: visibleFrame.maxY - size.height - 38)
        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.title = "codexeyes"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Keep the card in the desktop layer. Application windows naturally
        // cover it, so it is visible when the desktop is exposed only.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        panel.ignoresMouseEvents = true
        // Keep the card anchored to the desktop corner.
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: UsageWidget())
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: "codexeyes")
            button.image?.isTemplate = true
        }
        let menu = NSMenu()
        let show = NSMenuItem(title: "显示 codexeyes", action: #selector(showPanel), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 codexeyes", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    @objc private func showPanel() {
        panel?.orderFrontRegardless()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

struct CodexUsageSnapshot {
    var usedPercent: Double = 0
    var resetAt: Date?
    var windowMinutes = 10080
    var planType = "Codex"
    var windows: [CodexUsageWindow] = []
    var generatedTokens = 0
    var contextTokens = 0
    var dailyGenerated: [Date: Int] = [:]
    var hasData = false
}

struct CodexUsageWindow: Identifiable {
    let windowMinutes: Int
    let usedPercent: Double
    let resetAt: Date?

    var id: Int { windowMinutes }
    var title: String {
        if windowMinutes <= 360 { return "\(max(1, windowMinutes / 60)) 小时窗口" }
        if windowMinutes < 2_880 { return "24 小时窗口" }
        return "7 天窗口"
    }
    var percentText: String { "\(Int(usedPercent.rounded()))%" }
    var countdownText: String {
        guard let resetAt else { return "等待数据" }
        let seconds = max(0, Int(resetAt.timeIntervalSinceNow))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        if hours >= 24 { return "\(Int(ceil(Double(hours) / 24)))天后重置" }
        return "\(hours)小时 \(minutes)分后重置"
    }
}

struct AccountProfile {
    var name = "Codex"
    var email = ""
    var initials = "C"
    var isAuthenticated = false
    var avatarURL: URL? = nil
}

private struct AuthFile: Decodable {
    let tokens: AuthTokens?
}

private struct AuthTokens: Decodable {
    let idToken: String?

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
    }
}

private struct IdentityClaims: Decodable {
    let name: String?
    let email: String?
    let picture: String?
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case name
        case email
        case picture
        case avatarURL = "avatar_url"
    }
}

private enum CodexAccountReader {
    static func read() -> AccountProfile {
        let authURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")
        guard let data = try? Data(contentsOf: authURL),
              let auth = try? JSONDecoder().decode(AuthFile.self, from: data),
              let token = auth.tokens?.idToken,
              let claims = decodeClaims(from: token) else { return AccountProfile() }
        let name = claims.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? claims.name!.trimmingCharacters(in: .whitespacesAndNewlines)
            : "Codex"
        let avatarURL = (claims.picture ?? claims.avatarURL).flatMap(URL.init(string:))
        return AccountProfile(name: name, email: claims.email ?? "", initials: initials(for: name), isAuthenticated: true, avatarURL: avatarURL)
    }

    private static func decodeClaims(from token: String) -> IdentityClaims? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var encoded = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard let data = Data(base64Encoded: encoded) else { return nil }
        return try? JSONDecoder().decode(IdentityClaims.self, from: data)
    }

    private static func initials(for name: String) -> String {
        let parts = name.split(whereSeparator: { $0 == " " || $0 == "-" })
        if parts.count > 1 { return String(parts.prefix(2).compactMap { $0.first }).uppercased() }
        return String(name.prefix(2)).uppercased()
    }
}

private struct UsageLogEnvelope: Decodable {
    let timestamp: String?
    let payload: UsageLogPayload?
}

private struct UsageLogPayload: Decodable {
    let type: String?
    let info: UsageInfo?
    let rateLimits: RateLimits?

    enum CodingKeys: String, CodingKey {
        case type
        case info
        case rateLimits = "rate_limits"
    }
}

private struct UsageInfo: Decodable {
    let totalTokenUsage: TokenUsage?

    enum CodingKeys: String, CodingKey {
        case totalTokenUsage = "total_token_usage"
    }
}

private struct TokenUsage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

private struct RateLimits: Decodable {
    let primary: PrimaryLimit?
    let secondary: PrimaryLimit?
    let planType: String?

    enum CodingKeys: String, CodingKey {
        case primary
        case secondary
        case planType = "plan_type"
    }
}

private struct PrimaryLimit: Decodable {
    let usedPercent: Double?
    let windowMinutes: Int?
    let resetsAt: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case windowMinutes = "window_minutes"
        case resetsAt = "resets_at"
    }
}

private struct UsageRecord {
    let date: Date
    let output: Int
    let input: Int
    let limits: [PrimaryLimit]
    let planType: String?
}

private enum CodexUsageReader {
    static func read() -> CodexUsageSnapshot {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return CodexUsageSnapshot() }

        var files: [[UsageRecord]] = []
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { continue }
            var records: [UsageRecord] = []
            for line in contents.split(whereSeparator: \.isNewline) {
                guard let envelope = try? decoder.decode(UsageLogEnvelope.self, from: Data(line.utf8)),
                      let payload = envelope.payload,
                      payload.type == "token_count",
                      let info = payload.info,
                      let dateString = envelope.timestamp,
                      let date = formatter.date(from: dateString),
                      let totals = info.totalTokenUsage else { continue }
                records.append(UsageRecord(
                    date: date,
                    output: totals.outputTokens ?? 0,
                    input: totals.inputTokens ?? 0,
                    limits: [payload.rateLimits?.primary, payload.rateLimits?.secondary].compactMap { $0 },
                    planType: payload.rateLimits?.planType
                ))
            }
            if !records.isEmpty { files.append(records.sorted { $0.date < $1.date }) }
        }

        guard !files.isEmpty else { return CodexUsageSnapshot() }
        let latest = files.flatMap { $0 }.max { $0.date < $1.date }
        // A session can contain more than one rate-limit source (for example
        // the main Codex model and Codex Spark). Some sources report zero for
        // a window even while another source has the current account usage.
        // Keep all samples so a newer zero from one source cannot hide a real
        // value from the same active window.
        var windowsByMinutes: [Int: [(date: Date, limit: PrimaryLimit)]] = [:]
        for record in files.flatMap({ $0 }) {
            for limit in record.limits {
                guard let minutes = limit.windowMinutes, minutes > 0 else { continue }
                windowsByMinutes[minutes, default: []].append((date: record.date, limit: limit))
            }
        }
        let now = Date()
        let windows = windowsByMinutes.values
            .compactMap { samples -> CodexUsageWindow? in
                let active = samples.filter { sample in
                    guard let reset = sample.limit.resetsAt else { return true }
                    return Date(timeIntervalSince1970: reset) > now
                }
                guard let selected = active.max(by: { lhs, rhs in
                    let leftPercent = lhs.limit.usedPercent ?? 0
                    let rightPercent = rhs.limit.usedPercent ?? 0
                    if leftPercent != rightPercent { return leftPercent < rightPercent }
                    return lhs.date < rhs.date
                }) else { return nil }
                return CodexUsageWindow(
                    windowMinutes: selected.limit.windowMinutes ?? 10080,
                    usedPercent: min(100, max(0, selected.limit.usedPercent ?? 0)),
                    resetAt: selected.limit.resetsAt.map { Date(timeIntervalSince1970: $0) }
                )
            }
            .sorted { $0.windowMinutes < $1.windowMinutes }
        let mainWindow = windows.max { $0.windowMinutes < $1.windowMinutes }
        let usedPercent = mainWindow?.usedPercent ?? latest?.limits.first?.usedPercent ?? 0
        let windowMinutes = mainWindow?.windowMinutes ?? latest?.limits.first?.windowMinutes ?? 10080
        let resetAt = mainWindow?.resetAt
        let windowStart = resetAt?.addingTimeInterval(-Double(windowMinutes) * 60)
            ?? Date().addingTimeInterval(-Double(windowMinutes) * 60)
        var snapshot = CodexUsageSnapshot(
            usedPercent: min(100, max(0, usedPercent)),
            resetAt: resetAt,
            windowMinutes: windowMinutes,
            planType: latest?.planType ?? "Codex",
            windows: windows,
            hasData: true
        )
        let calendar = Calendar.current

        for records in files {
            var previousOutput: Int?
            var previousInput: Int?
            for record in records {
                if record.date < windowStart {
                    previousOutput = record.output
                    previousInput = record.input
                    continue
                }
                // If a thread starts inside the current window, its first total is
                // already part of this cycle. Older threads use the delta from the
                // last event before the window.
                let outputDelta = max(0, previousOutput.map { record.output - $0 } ?? record.output)
                let inputDelta = max(0, previousInput.map { record.input - $0 } ?? record.input)
                snapshot.generatedTokens += outputDelta
                snapshot.contextTokens += inputDelta
                let day = calendar.startOfDay(for: record.date)
                snapshot.dailyGenerated[day, default: 0] += outputDelta
                previousOutput = record.output
                previousInput = record.input
            }
        }
        return snapshot
    }
}

private final class UsageFileWatcher {
    private let root: URL
    private let queue = DispatchQueue(label: "local.codex.eyes.usage-watcher", qos: .utility)
    private let onChange: () -> Void
    private var directorySource: DispatchSourceFileSystemObject?
    private var fileSources: [URL: DispatchSourceFileSystemObject] = [:]
    private var notificationScheduled = false

    init(root: URL, onChange: @escaping () -> Void) {
        self.root = root
        self.onChange = onChange
    }

    deinit {
        directorySource?.cancel()
        for source in fileSources.values { source.cancel() }
    }

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            self.installDirectoryWatcher()
            self.refreshFileWatchers()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.directorySource?.cancel()
            self.directorySource = nil
            for source in self.fileSources.values { source.cancel() }
            self.fileSources.removeAll()
        }
    }

    private func installDirectoryWatcher() {
        guard directorySource == nil else { return }
        let descriptor = open(root.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.refreshFileWatchers()
            self?.scheduleNotification()
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        directorySource = source
    }

    private func refreshFileWatchers() {
        let currentFiles = Set(jsonlFiles())
        for url in currentFiles where fileSources[url] == nil {
            installFileWatcher(for: url)
        }
        let staleFiles = fileSources.keys.filter { !currentFiles.contains($0) }
        for url in staleFiles {
            fileSources.removeValue(forKey: url)?.cancel()
        }
    }

    private func jsonlFiles() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "jsonl" else { return nil }
            return url.standardizedFileURL
        }
    }

    private func installFileWatcher(for url: URL) {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .rename, .delete],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.scheduleNotification()
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        fileSources[url] = source
    }

    private func scheduleNotification() {
        guard !notificationScheduled else { return }
        notificationScheduled = true
        queue.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.notificationScheduled = false
            DispatchQueue.main.async { [weak self] in self?.onChange() }
        }
    }
}

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot = CodexUsageSnapshot()
    @Published private(set) var isLoading = false
    @Published private(set) var isSessionActive = true
    private lazy var watcher: UsageFileWatcher = {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
        return UsageFileWatcher(root: root) { [weak self] in self?.refresh() }
    }()
    private var sessionObservers: [NSObjectProtocol] = []

    init() {
        watcher.start()
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        sessionObservers.append(workspaceCenter.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.setSessionActive(false) }
        })
        sessionObservers.append(workspaceCenter.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.setSessionActive(true) }
        })
    }

    deinit {
        for observer in sessionObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    var usedPercent: Int { Int(snapshot.usedPercent.rounded()) }
    var planType: String { snapshot.planType.uppercased() }
    var generatedText: String { Self.formatTokens(snapshot.generatedTokens) }
    var contextText: String { Self.formatTokens(snapshot.contextTokens) }
    var usageAccent: Color {
        switch snapshot.usedPercent {
        case 95...: return Color(red: 0.98, green: 0.34, blue: 0.43)
        case 80..<95: return Color(red: 1.0, green: 0.63, blue: 0.24)
        default: return accent
        }
    }
    var usageRingGradient: AngularGradient {
        AngularGradient(
            colors: [usageAccent.opacity(0.35), usageAccent, Color.white.opacity(0.72), usageAccent],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }
    var resetText: String {
        guard let resetAt = snapshot.resetAt else { return "等待 codexeyes 数据" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月 d日"
        return "\(formatter.string(from: resetAt))重置"
    }
    var daysLeftText: String {
        guard let resetAt = snapshot.resetAt else { return "—" }
        let days = max(0, Int(ceil(resetAt.timeIntervalSinceNow / 86_400)))
        return "\(days) 天"
    }

    private func setSessionActive(_ active: Bool) {
        guard isSessionActive != active else { return }
        isSessionActive = active
        if active {
            watcher.start()
            refresh()
        } else {
            watcher.stop()
        }
    }

    func refresh() {
        guard isSessionActive, !isLoading else { return }
        isLoading = true
        snapshot = CodexUsageReader.read()
        isLoading = false
    }

    func copySummary(for account: AccountProfile) {
        let text = "codexeyes · (account.name) · (usedPercent)% · 生成 (generatedText) · 上下文 (contextText) · (resetText)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func chartValues(days: Int) -> [Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<days).map { offset in
            let date = calendar.date(byAdding: .day, value: offset - days + 1, to: today) ?? today
            return Double(snapshot.dailyGenerated[date] ?? 0)
        }
    }

    func chartLabels(days: Int) -> [String] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let indices = days == 7 ? Array(0..<days) : [0, 7, 14, 21, 29]
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return indices.map { offset in
            let date = calendar.date(byAdding: .day, value: offset - days + 1, to: today) ?? today
            return offset == days - 1 ? "今天" : formatter.string(from: date)
        }
    }

    private static func formatTokens(_ count: Int) -> String {
        switch count {
        case 1_000_000...: return String(format: "%.2fM", Double(count) / 1_000_000)
        case 1_000...: return String(format: "%.1fk", Double(count) / 1_000)
        default: return "\(count)"
        }
    }
}

struct UsageWidget: View {
    @StateObject private var usageStore = UsageStore()
    private let account = CodexAccountReader.read()

    private var statusMessage: String? {
        if !account.isAuthenticated { return "请登录 Codex" }
        if !usageStore.snapshot.hasData { return usageStore.isLoading ? "正在读取数据" : "等待 Codex 数据" }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            accountRow
            summary
                .contentShape(Rectangle())
                .onTapGesture { usageStore.copySummary(for: account) }
            progressMeter
            stats
        }
        .padding(.horizontal, 10)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(width: 260, height: 285)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.28), lineWidth: 1))
        .preferredColorScheme(.dark)
        .onAppear { usageStore.refresh() }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in usageStore.refresh() }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 7) {
                Circle().fill(usageStore.usageAccent).frame(width: 5, height: 5)
                Text("CODEXEYES")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(subtle)
            }
        }
    }

    private var accountRow: some View {
        HStack(spacing: 11) {
            AccountAvatar(profile: account)
            VStack(alignment: .leading, spacing: 3) {
                Text(account.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(ink)
                HStack(spacing: 5) {
                    Text(usageStore.planType).font(.system(size: 7, weight: .bold, design: .rounded)).tracking(0.5).foregroundStyle(.white).padding(.horizontal, 4).padding(.vertical, 2).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.32)))
                }
            }
            .frame(maxWidth: 175, alignment: .leading)
        }
        .padding(.top, 15)
    }

    private var summary: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("本周期已使用").font(.system(size: 10)).foregroundStyle(subtle)
                HStack(alignment: .lastTextBaseline, spacing: 3) { Text("\(usageStore.usedPercent)").font(.system(size: 47, weight: .medium, design: .monospaced)).tracking(-4).foregroundStyle(ink); Text("%").font(.system(size: 20, weight: .medium)).foregroundStyle(subtle) }
                HStack(spacing: 0) {
                    Text("还剩 ").foregroundStyle(subtle)
                    Text(usageStore.daysLeftText).bold().foregroundStyle(ink)
                    Text(" · \(usageStore.resetText)").foregroundStyle(subtle)
                }
                .font(.system(size: 10))
            }
            Spacer()
            ZStack {
                Circle().stroke(Color.white.opacity(0.16), lineWidth: 7)
                Circle().trim(from: 0, to: usageStore.snapshot.usedPercent / 100).stroke(usageStore.usageRingGradient, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.35), value: usageStore.snapshot.usedPercent)
                Text("用量").font(.system(size: 9)).foregroundStyle(subtle)
            }.frame(width: 70, height: 70).offset(x: -12)
        }
        .padding(.top, 21)
    }

    private var progressMeter: some View {
        GeometryReader { proxy in
            Capsule().fill(Color.white.opacity(0.14))
                .overlay(alignment: .leading) {
                    Capsule().fill(LinearGradient(colors: [usageStore.usageAccent.opacity(0.8), usageStore.usageAccent], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * CGFloat(usageStore.snapshot.usedPercent / 100))
                        .animation(.easeOut(duration: 0.35), value: usageStore.snapshot.usedPercent)
                }
                .overlay(alignment: .topLeading) {
                    if let statusMessage {
                        Text(statusMessage).font(.system(size: 9)).foregroundStyle(subtle).offset(y: -16)
                    }
                }
        }
        .frame(height: 7)
        .padding(.vertical, 16)
    }

    private var stats: some View {
        HStack(alignment: .top, spacing: 0) {
            StatView(label: "生成 tokens", value: usageStore.generatedText)
            Divider().frame(height: 32).padding(.horizontal, 10)
            StatView(label: "上下文 tokens", value: usageStore.contextText)
        }
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(softLine).frame(height: 1) }
    }

}

private struct AccountAvatar: View {
    let profile: AccountProfile

    @ViewBuilder
    private var fallback: some View {
        Text(profile.initials)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.65, green: 0.61, blue: 1), accent], startPoint: .topLeading, endPoint: .bottomTrailing))
            if let url = profile.avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: accent.opacity(0.2), radius: 8, y: 4)
    }
}

struct StatView: View {
    let label: String
    let value: String
    var body: some View { VStack(alignment: .leading, spacing: 3) { Text(label).font(.system(size: 10)).foregroundStyle(subtle); Text(value).font(.system(size: 18, weight: .medium, design: .monospaced)).tracking(-1).foregroundStyle(ink).lineLimit(1) }.frame(maxWidth: .infinity, alignment: .leading).frame(height: 32, alignment: .top) }
}

struct BarChart: View {
    let values: [Double]
    var body: some View {
        GeometryReader { proxy in
            let maxValue = values.max() ?? 1
            HStack(alignment: .bottom, spacing: values.count > 10 ? 4 : 9) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(index == values.count - 1 ? accent : accent.opacity(0.22))
                            .frame(height: max(5, proxy.size.height * 0.78 * value / maxValue))
                    }
                }
            }
            .padding(.horizontal, 2)
            .background { VStack(spacing: 0) { ForEach(0..<3, id: \.self) { _ in Rectangle().fill(softLine.opacity(0.7)).frame(height: 1); Spacer() }; Rectangle().fill(softLine).frame(height: 1) } }
        }
    }
}
