import AppKit
import CoverCore

private final class CoverPanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

@MainActor
final class OverlayController {
    private var panels: [CGDirectDisplayID: [CoverPanel]] = [:]

    func apply(segments: [CoverSegment], displays: [DisplayInfo], heights: [CGDirectDisplayID: CGFloat], images: [CGDirectDisplayID: CGImage]) {
        let primaryHeight = CGDisplayBounds(CGMainDisplayID()).height
        var used: Set<CGDirectDisplayID> = []

        for display in displays {
            guard let height = heights[display.id] else { continue }
            used.insert(display.id)
            var displayPanels = panels[display.id] ?? []
            while displayPanels.count < segments.count { displayPanels.append(makePanel()) }
            while displayPanels.count > segments.count { displayPanels.removeLast().orderOut(nil) }

            for (panel, segment) in zip(displayPanels, segments) {
                let rect = CoverLayout.rect(for: segment, display: display.bounds, menuBarHeight: height)
                panel.setFrame(CoverLayout.appKitRect(rect, primaryHeight: primaryHeight), display: false)
                setBackground(of: panel, rect: rect, display: display, image: images[display.id])
                panel.orderFrontRegardless()
            }
            panels[display.id] = displayPanels
        }

        for (id, stale) in panels where !used.contains(id) {
            stale.forEach { $0.orderOut(nil) }
            panels[id] = nil
        }
    }

    func hideAll() {
        panels.values.joined().forEach { $0.orderOut(nil) }
        panels = [:]
    }

    private func makePanel() -> CoverPanel {
        let panel = CoverPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // Status items are drawn into the menu bar at level 24/25, so one above is enough to sit on top while menus still open above.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque = true
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.contentView?.wantsLayer = true
        return panel
    }

    private func setBackground(of panel: NSPanel, rect: CGRect, display: DisplayInfo, image: CGImage?) {
        guard let layer = panel.contentView?.layer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let image {
            let scale = CGFloat(image.width) / display.bounds.width
            let crop = CGRect(x: (rect.minX - display.bounds.minX) * scale, y: 0, width: rect.width * scale, height: CGFloat(image.height))
            layer.contents = image.cropping(to: crop.integral)
            layer.contentsGravity = .resize
        } else {
            layer.contents = nil
            layer.backgroundColor = NSColor(white: 0.12, alpha: 1).cgColor
        }
        CATransaction.commit()
    }
}
