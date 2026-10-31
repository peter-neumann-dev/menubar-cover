import CoverCore
import ScreenCaptureKit

/// Captures the empty menu bar background (wallpaper plus the system's darkening layer) per display.
@MainActor
final class BackgroundCapture {
    private(set) var images: [CGDirectDisplayID: CGImage] = [:]
    private(set) var lastRefresh = Date.distantPast

    func refresh(displays: [DisplayInfo], heights: [CGDirectDisplayID: CGFloat]) async {
        lastRefresh = Date()
        guard CGPreflightScreenCaptureAccess(),
              let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) else {
            images = [:]
            return
        }

        var captured: [CGDirectDisplayID: CGImage] = [:]
        for display in displays {
            guard let height = heights[display.id],
                  let scDisplay = content.displays.first(where: { $0.displayID == display.id }) else { continue }
            let layers = content.windows.filter {
                ($0.title == "Wallpaper" || $0.title == "underbelly") && $0.frame.intersects(display.bounds)
            }
            guard !layers.isEmpty else { continue }

            let filter = SCContentFilter(display: scDisplay, including: layers)
            let config = SCStreamConfiguration()
            config.sourceRect = CGRect(x: 0, y: 0, width: display.bounds.width, height: height)
            config.width = Int(display.bounds.width * CGFloat(filter.pointPixelScale))
            config.height = Int(height * CGFloat(filter.pointPixelScale))
            config.showsCursor = false
            captured[display.id] = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        }
        images = captured
    }

    /// Snapshots of each item, taken without our own cover panels. All menu bars show the same items aligned
    /// to the right edge, so they are cut from one display whose menu bar is visible (not full screen).
    func thumbnails(of items: [StatusItem], displays: [DisplayInfo], heights: [CGDirectDisplayID: CGFloat]) async -> [String: CGImage] {
        guard CGPreflightScreenCaptureAccess(),
              let source = displays.first(where: { heights[$0.id] != nil }), let barHeight = heights[source.id],
              let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
              let scDisplay = content.displays.first(where: { $0.displayID == source.id }) else { return [:] }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let filter = SCContentFilter(display: scDisplay, excludingApplications: content.applications.filter { $0.processID == ownPID }, exceptingWindows: [])
        let scale = CGFloat(filter.pointPixelScale)
        let config = SCStreamConfiguration()
        config.sourceRect = CGRect(x: 0, y: 0, width: source.bounds.width, height: barHeight)
        config.width = Int(source.bounds.width * scale)
        config.height = Int(barHeight * scale)
        config.showsCursor = false
        guard let strip = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) else { return [:] }

        let reportedOn = displays.map(\.bounds)
        var result: [String: CGImage] = [:]
        for item in items {
            guard let display = CoverLayout.menuBarDisplay(of: item.frame, in: reportedOn) else { continue }
            let x = source.bounds.width + item.frame.minX - display.maxX
            let height = min(item.frame.height, barHeight)
            let crop = CGRect(x: x, y: (barHeight - height) / 2, width: item.frame.width, height: height)
            result[item.id] = strip.cropping(to: CGRect(x: crop.minX * scale, y: crop.minY * scale, width: crop.width * scale, height: crop.height * scale).integral)
        }
        return result
    }

    func invalidate() {
        lastRefresh = .distantPast
    }
}
