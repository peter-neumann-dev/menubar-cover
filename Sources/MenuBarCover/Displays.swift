import AppKit

struct DisplayInfo: Identifiable, Equatable, Sendable {
    let id: CGDirectDisplayID
    let uuid: String
    let name: String
    let isMain: Bool
    /// Global top-left coordinates.
    let bounds: CGRect
}

@MainActor
enum Displays {
    static func current() -> [DisplayInfo] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let id = CGDirectDisplayID(number.uint32Value)
            let uuid = CGDisplayCreateUUIDFromDisplayID(id).map { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String } ?? "\(id)"
            return DisplayInfo(id: id, uuid: uuid, name: screen.localizedName, isMain: CGDisplayIsMain(id) != 0, bounds: CGDisplayBounds(id))
        }
    }

    /// Heights of the visible menu bars; a display without an entry has its menu bar hidden (e.g. full screen).
    /// Returns nil when window names are unreadable (no Screen Recording permission).
    static func menuBarHeights(for displays: [DisplayInfo]) -> [CGDirectDisplayID: CGFloat]? {
        guard CGPreflightScreenCaptureAccess(),
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return nil }
        var heights: [CGDirectDisplayID: CGFloat] = [:]
        var fullScreen: Set<CGDirectDisplayID> = []
        for window in list {
            guard let name = window[kCGWindowName as String] as? String, name == "Menubar" || name == "Fullscreen Backdrop",
                  let dict = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: dict),
                  let display = displays.first(where: { $0.bounds.minX == rect.minX && $0.bounds.minY == rect.minY }) else { continue }
            if name == "Menubar" { heights[display.id] = rect.height } else { fullScreen.insert(display.id) }
        }
        return heights.filter { !fullScreen.contains($0.key) }
    }

    static func fallbackMenuBarHeight(for display: DisplayInfo) -> CGFloat {
        let screen = NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.id }
        if let screen, screen.frame.maxY - screen.visibleFrame.maxY > 0 {
            return screen.frame.maxY - screen.visibleFrame.maxY
        }
        return NSStatusBar.system.thickness
    }
}
