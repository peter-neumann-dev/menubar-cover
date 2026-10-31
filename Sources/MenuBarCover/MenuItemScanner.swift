import AppKit

struct RunningApp: Sendable {
    let pid: pid_t
    let bundleID: String
    let name: String
    let isSystem: Bool
}

struct StatusItem: Identifiable, Sendable, Equatable {
    /// Bundle ID plus position within the app's items; Apple's items carry no other stable label.
    let id: String
    let appName: String
    let isSystem: Bool
    /// Global top-left coordinates.
    let frame: CGRect
}

/// Reads status item frames via Accessibility. Runs off the main thread because unresponsive apps can block AX calls.
final class MenuItemScanner: @unchecked Sendable {
    private let lock = NSLock()
    private var appsWithItems: Set<pid_t> = []
    private var discovering = false
    private var lastDiscovery = Date.distantPast

    @MainActor
    static func runningApps() -> [RunningApp] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications
            .filter { $0.processIdentifier != ownPID && $0.activationPolicy != .prohibited }
            .map { app in
                let bundleID = app.bundleIdentifier ?? "pid.\(app.processIdentifier)"
                let isSystem = bundleID.hasPrefix("com.apple.")
                return RunningApp(pid: app.processIdentifier, bundleID: bundleID, name: isSystem ? "macOS" : (app.localizedName ?? bundleID), isSystem: isSystem)
            }
    }

    /// Asking every running app takes seconds, so finding new status item owners runs apart from the fast position scan.
    func discoverInBackground(_ apps: [RunningApp]) {
        let start = lock.withLock {
            guard !discovering, Date().timeIntervalSince(lastDiscovery) > 3 else { return false }
            discovering = true
            return true
        }
        guard start else { return }
        Task.detached { [self] in
            let found = Set(apps.filter { !Self.statusItemFrames(pid: $0.pid).isEmpty }.map(\.pid))
            lock.withLock {
                appsWithItems = found
                discovering = false
                lastDiscovery = Date()
            }
        }
    }

    func scan(_ apps: [RunningApp]) -> [StatusItem] {
        let known = lock.withLock { appsWithItems }
        var items: [StatusItem] = []
        for app in apps where known.contains(app.pid) {
            let frames = Self.statusItemFrames(pid: app.pid)
            // Numbered from the right: new items such as the recording indicator appear on the left.
            items += frames.enumerated().map { index, frame in
                StatusItem(id: "\(app.bundleID)#\(frames.count - 1 - index)", appName: app.name, isSystem: app.isSystem, frame: frame)
            }
        }
        return items
    }

    private static func statusItemFrames(pid: pid_t) -> [CGRect] {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.25)
        guard let bar: AXUIElement = attribute(app, "AXExtrasMenuBar"),
              let children: [AXUIElement] = attribute(bar, kAXChildrenAttribute) else { return [] }
        return children.compactMap { child in
            guard let position: AXValue = attribute(child, kAXPositionAttribute),
                  let size: AXValue = attribute(child, kAXSizeAttribute) else { return nil }
            var point = CGPoint.zero
            var extent = CGSize.zero
            AXValueGetValue(position, .cgPoint, &point)
            AXValueGetValue(size, .cgSize, &extent)
            return CGRect(origin: point, size: extent)
        }
    }

    private static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
