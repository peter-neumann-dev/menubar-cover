import CoreGraphics
import Testing
@testable import CoverCore

// Real AX output from a three-display setup: third-party items report on display 2, Apple items on display 1.
private let studio1 = CGRect(x: 0, y: 0, width: 2560, height: 1440)
private let studio2 = CGRect(x: 2560, y: 0, width: 2560, height: 1440)
private let builtIn = CGRect(x: 5120, y: 323, width: 1728, height: 1117)

private func item(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, system: Bool = false) -> MenuBarItem {
    MenuBarItem(frame: CGRect(x: x, y: y, width: w, height: h), isCovered: !system)
}

private let realItems: [MenuBarItem] = [
    item(2193, 4.5, 22, 22, system: true),   // Time Machine
    item(2306, 0, 22, 30, system: true),     // Wi-Fi
    item(2344, 0, 22, 30, system: true),     // Sound
    item(2382, 0, 26, 30, system: true),     // Control Center
    item(2421, 0, 116, 30, system: true),    // Clock
    item(7, 1428, 24, 24),                   // hidden (overflow)
    item(4782, 3.5, 76.5, 24),               // BatFi
    item(4533, 3.5, 24, 24),                 // Lungo
    item(4712, 3.5, 34, 24),                 // noTunes
    item(4638, 3.5, 38, 24),                 // In Your Face
    item(4410, 3.5, 116.5, 24),              // OpenUsage
    item(4563, 3.5, 36, 24),                 // CleanShot X
    item(1186, 242.5, 34, 24),               // Slack, not in a menu bar
    item(4682, 3.5, 24, 24),                 // JetBrains Toolbox
    item(4597, 3.5, 43, 24),                 // Superwhisper
]

@Test func ignoresItemsOutsideAnyMenuBar() {
    let segments = CoverLayout.segments(items: [item(7, 1428, 24, 24), item(1186, 242.5, 34, 24)], displays: [studio1, studio2])
    #expect(segments.isEmpty)
}

@Test func mergesNeighbouringCoveredItemsAndSplitsAtVisibleOnes() {
    let segments = CoverLayout.segments(items: realItems, displays: [studio1, studio2, builtIn])
    #expect(segments.count == 2)
    // OpenUsage … noTunes, stopping before Time Machine
    #expect(segments[0].start == -710 - CoverLayout.maxPadding)
    #expect(segments[0].end == -374 + CoverLayout.maxPadding)
    // BatFi alone, between Time Machine and Wi-Fi
    #expect(segments[1].start == -338 - CoverLayout.maxPadding)
    #expect(segments[1].end == -261.5 + CoverLayout.maxPadding)
}

@Test func returnsNothingWhenNoItemIsCovered() {
    let segments = CoverLayout.segments(items: realItems.filter { !$0.isCovered }, displays: [studio1])
    #expect(segments.isEmpty)
}

@Test func mapsSegmentsOntoAnyDisplayFromTheRightEdge() {
    let rect = CoverLayout.rect(for: CoverSegment(start: -700, end: -260), display: builtIn, menuBarHeight: 33)
    #expect(rect == CGRect(x: 6848 - 700, y: 323, width: 440, height: 33))
}

@Test func convertsTopLeftRectsToAppKitCoordinates() {
    let rect = CoverLayout.appKitRect(CGRect(x: 6148, y: 323, width: 440, height: 33), primaryHeight: 1440)
    #expect(rect == CGRect(x: 6148, y: 1440 - 356, width: 440, height: 33))
}

@Test func coveringASystemItemJoinsItsNeighbours() {
    let items = realItems.map { item in
        var item = item
        if item.frame.minX == 2193 { item.isCovered = true } // Time Machine
        return item
    }
    let segments = CoverLayout.segments(items: items, displays: [studio1, studio2])
    #expect(segments.count == 1)
    #expect(segments[0].end == -261.5 + CoverLayout.maxPadding)
}

@Test func findsTheMenuBarDisplayOfAnItem() {
    #expect(CoverLayout.menuBarDisplay(of: CGRect(x: 4410, y: 3.5, width: 116.5, height: 24), in: [studio1, studio2]) == studio2)
    #expect(CoverLayout.menuBarDisplay(of: CGRect(x: 7, y: 1428, width: 24, height: 24), in: [studio1, studio2]) == nil)
}

@Test func leavesRoomForAnUnknownRecordingIndicatorOnTheLeft() {
    // The indicator reports 20pt at x 1817 but draws a pill up to ~1844.
    let segments = CoverLayout.segments(items: [item(4410, 3.5, 116.5, 24)], displays: [studio2])
    #expect(segments[0].start > 1844 - 2560)
}
