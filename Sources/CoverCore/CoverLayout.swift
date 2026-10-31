import CoreGraphics

/// A status item in global top-left screen coordinates, as reported by Accessibility.
public struct MenuBarItem: Sendable, Equatable {
    public var frame: CGRect
    public var isCovered: Bool

    public init(frame: CGRect, isCovered: Bool) {
        self.frame = frame
        self.isCovered = isCovered
    }
}

/// A horizontal range measured from a display's right edge (negative values).
public struct CoverSegment: Sendable, Equatable {
    public var start: CGFloat
    public var end: CGFloat

    public init(start: CGFloat, end: CGFloat) {
        self.start = start
        self.end = end
    }
}

public enum CoverLayout {
    /// Kept tiny: some system items (e.g. the recording indicator) draw wider than their reported frame.
    public static let maxPadding: CGFloat = 1
    static let menuBarProbeHeight: CGFloat = 50

    /// Every display shows the same status items aligned to its right edge, so segments are display-independent.
    public static func segments(items: [MenuBarItem], displays: [CGRect]) -> [CoverSegment] {
        let placed = items.compactMap { item -> (start: CGFloat, end: CGFloat, isCovered: Bool)? in
            guard let display = menuBarDisplay(of: item.frame, in: displays) else { return nil }
            return (item.frame.minX - display.maxX, item.frame.maxX - display.maxX, item.isCovered)
        }.sorted { $0.start < $1.start }

        var segments: [CoverSegment] = []
        var index = 0
        while index < placed.count {
            guard placed[index].isCovered else { index += 1; continue }
            let first = index
            while index + 1 < placed.count, placed[index + 1].isCovered { index += 1 }
            let last = index

            var start = placed[first].start - maxPadding
            if first > 0 {
                start = placed[first].start - min(maxPadding, max(0, placed[first].start - placed[first - 1].end) / 2)
            }
            var end = placed[last].end + maxPadding
            if last + 1 < placed.count {
                end = placed[last].end + min(maxPadding, max(0, placed[last + 1].start - placed[last].end) / 2)
            }
            segments.append(CoverSegment(start: start, end: end))
            index += 1
        }
        return segments
    }

    /// The display whose menu bar contains the item; nil for overflowed or off-bar items.
    public static func menuBarDisplay(of frame: CGRect, in displays: [CGRect]) -> CGRect? {
        displays.first {
            frame.midX >= $0.minX && frame.midX < $0.maxX && frame.midY >= $0.minY && frame.midY < $0.minY + menuBarProbeHeight
        }
    }

    public static func rect(for segment: CoverSegment, display: CGRect, menuBarHeight: CGFloat) -> CGRect {
        CGRect(x: display.maxX + segment.start, y: display.minY, width: segment.end - segment.start, height: menuBarHeight)
    }

    /// Converts a global top-left rect into AppKit's bottom-left coordinate space.
    public static func appKitRect(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
