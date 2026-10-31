import AppKit
import CoverCore
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    static let agent = SMAppService.agent(plistName: "dev.peter-neumann.MenuBarCover.agent.plist")

    @Published var isActive: Bool {
        didSet { defaults.set(isActive, forKey: "isActive"); restartLoop() }
    }
    @Published var coverAllDisplays: Bool {
        didSet { defaults.set(coverAllDisplays, forKey: "coverAllDisplays"); triggerUpdate() }
    }
    @Published var selectedDisplayUUIDs: Set<String> {
        didSet { defaults.set(Array(selectedDisplayUUIDs), forKey: "selectedDisplayUUIDs"); triggerUpdate() }
    }
    @Published private var itemVisibility: [String: Bool] {
        didSet { defaults.set(itemVisibility, forKey: "itemVisibility"); triggerUpdate() }
    }
    @Published var launchAtLogin: Bool {
        didSet { updateLoginItem() }
    }
    @Published private(set) var displays: [DisplayInfo] = []
    @Published private(set) var items: [StatusItem] = []
    @Published private(set) var thumbnails: [String: CGImage] = [:]
    @Published private(set) var hasAccessibility = false
    @Published private(set) var hasScreenRecording = false

    var settingsVisible = false {
        didSet { restartLoop() }
    }

    private let defaults = UserDefaults.standard
    private let scanner = MenuItemScanner()
    private let capture = BackgroundCapture()
    private let overlays = OverlayController()
    private var loop: Task<Void, Never>?
    private var lastThumbnails = Date.distantPast

    init() {
        defaults.register(defaults: ["coverAllDisplays": true])
        isActive = defaults.bool(forKey: "isActive")
        coverAllDisplays = defaults.bool(forKey: "coverAllDisplays")
        selectedDisplayUUIDs = Set(defaults.stringArray(forKey: "selectedDisplayUUIDs") ?? [])
        itemVisibility = defaults.dictionary(forKey: "itemVisibility") as? [String: Bool] ?? [:]
        launchAtLogin = Self.agent.status == .enabled
        refreshEnvironment()

        let center = NotificationCenter.default
        center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.capture.invalidate(); self?.triggerUpdate() }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.capture.invalidate(); self?.triggerUpdate() }
        }
        restartLoop()
    }

    func isCovered(_ display: DisplayInfo) -> Bool {
        coverAllDisplays || selectedDisplayUUIDs.contains(display.uuid)
    }

    func setCovered(_ display: DisplayInfo, _ covered: Bool) {
        if covered { selectedDisplayUUIDs.insert(display.uuid) } else { selectedDisplayUUIDs.remove(display.uuid) }
    }

    /// Apple's items stay visible by default, everything else is covered.
    func isVisible(_ item: StatusItem) -> Bool {
        itemVisibility[item.id] ?? item.isSystem
    }

    func setVisible(_ item: StatusItem, _ visible: Bool) {
        itemVisibility[item.id] = visible
    }

    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        openPrivacyPane("Privacy_Accessibility")
    }

    func requestScreenRecording() {
        if !CGRequestScreenCaptureAccess() { openPrivacyPane("Privacy_ScreenCapture") }
    }

    func refreshEnvironment() {
        let current = Displays.current()
        if current != displays { displays = current }
        hasAccessibility = AXIsProcessTrusted()
        hasScreenRecording = CGPreflightScreenCaptureAccess()
    }

    private func openPrivacyPane(_ anchor: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!)
    }

    private func updateLoginItem() {
        do {
            if launchAtLogin { try Self.agent.register() } else { try Self.agent.unregister() }
        } catch {
            NSLog("MenuBarCover: login item change failed: \(error)")
        }
    }

    private func restartLoop() {
        loop?.cancel()
        loop = nil
        if !isActive { overlays.hideAll() }
        guard isActive || settingsVisible else { return }
        capture.invalidate()
        lastThumbnails = .distantPast
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.update()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func triggerUpdate() {
        guard isActive || settingsVisible else { return }
        Task { await update() }
    }

    private func update() async {
        refreshEnvironment()
        let displayRects = displays.map(\.bounds)

        let apps = MenuItemScanner.runningApps()
        let scanner = scanner
        scanner.discoverInBackground(apps)
        let scanned = await Task.detached { scanner.scan(apps) }.value
        let visible = scanned
            .compactMap { item in CoverLayout.menuBarDisplay(of: item.frame, in: displayRects).map { (item, item.frame.minX - $0.maxX) } }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
        if visible != items { items = visible }

        let heights = Displays.menuBarHeights(for: displays)
            ?? Dictionary(uniqueKeysWithValues: displays.map { ($0.id, Displays.fallbackMenuBarHeight(for: $0)) })
        if settingsVisible, Date().timeIntervalSince(lastThumbnails) > 2 {
            lastThumbnails = Date()
            thumbnails = await capture.thumbnails(of: items, displays: displays, heights: heights)
        }

        guard isActive else { return }
        let targets = displays.filter(isCovered)
        if Date().timeIntervalSince(capture.lastRefresh) > 15 {
            await capture.refresh(displays: targets, heights: heights)
            guard isActive else { return }
        }

        let layoutItems = items.map { MenuBarItem(frame: $0.frame, isCovered: !isVisible($0)) }
        let segments = CoverLayout.segments(items: layoutItems, displays: displayRects)
        overlays.apply(segments: segments, displays: targets, heights: heights, images: capture.images)
    }
}
