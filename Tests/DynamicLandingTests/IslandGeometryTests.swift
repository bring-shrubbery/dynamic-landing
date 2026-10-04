// DynamicLanding — IslandGeometryTests.swift
import CoreGraphics
import Testing
@testable import DynamicLanding

struct IslandGeometryTests {
    let notched = ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), notchSize: CGSize(width: 200, height: 38), menuBarHeight: 38)
    let notchless = ScreenMetrics(frame: CGRect(x: 100, y: 50, width: 2560, height: 1440), notchSize: nil, menuBarHeight: 24)
    let slots = (leading: CGSize(width: 24, height: 20), trailing: CGSize(width: 40, height: 16))
    let content = CGSize(width: 260, height: 64)
    let styles: [IslandStyle] = [.automatic, .notch(topCornerRadius: 12, bottomCornerRadius: 18), .pill(cornerRadius: 14)]
    let states: [IslandState] = [.hidden, .compact, .expanded]

    private func layout(_ state: IslandState, _ metrics: ScreenMetrics, _ style: IslandStyle, content: CGSize? = nil) -> IslandLayout {
        var c = IslandConfiguration(); c.style = style
        return IslandGeometry.layout(state: state, metrics: metrics, configuration: c, compactSlotSizes: slots, expandedContentSize: content ?? self.content)
    }

    @Test func theTopEdgeIsPinnedAndTheIslandIsCentredEverywhere() {
        for metrics in [notched, notchless] {
            for style in styles {
                for state in states {
                    let l = layout(state, metrics, style)
                    #expect(l.rect.maxY == metrics.frame.maxY, "\(state) \(style) maxY")
                    #expect(abs(l.rect.midX - metrics.frame.midX) < 0.5, "\(state) \(style) midX")
                    #expect(l.rect.width <= metrics.frame.width / 2 && l.rect.height <= metrics.frame.height / 2)
                }
            }
        }
    }

    @Test func hiddenIsTheNotchOnANotchedScreenAndNothingOnANotchlessOne() {
        #expect(layout(.hidden, notched, .automatic).rect == notched.notchRect!)
        let none = layout(.hidden, notchless, .automatic).rect
        #expect(none.height == 0 && none.maxY == notchless.frame.maxY)
    }

    @Test func theNotchLookNeverGetsNarrowerThanTheNotch() {
        for state in states {
            let l = layout(state, notched, .automatic)
            #expect(l.look == .notch)
            #expect(l.rect.width >= notched.notchSize!.width, "\(state)")
            #expect(l.rect.height >= notched.notchSize!.height || state == .hidden)
        }
    }

    @Test func compactSlotsFlankTheNotchWithoutOverlappingIt() throws {
        let l = layout(.compact, notched, .automatic)
        let leading = try #require(l.leadingSlot), trailing = try #require(l.trailingSlot)
        // Island-local coordinates, top-left origin: the notch occupies the middle 200 pt.
        let notchMinX = (l.rect.width - 200) / 2, notchMaxX = notchMinX + 200
        #expect(leading.maxX == notchMinX - 8 && trailing.minX == notchMaxX + 8)
        #expect(leading.width == slots.leading.width && trailing.width == slots.trailing.width)
        #expect(l.rect.height == 38)
        #expect(l.rect.width == CGFloat(200 + 2 * (15 + 40 + 8)))   // the wider slot sets both sides
    }

    @Test func compactOnAPillIsTwoSlotsWithAGap() throws {
        let l = layout(.compact, notchless, .automatic)
        #expect(l.look == .pill)
        #expect(l.rect.height == 32)
        let leading = try #require(l.leadingSlot), trailing = try #require(l.trailingSlot)
        #expect(trailing.minX - leading.maxX == 8)
        #expect(l.rect.width == CGFloat(24 + 40 + 3 * 8))
    }

    @Test func expandedWrapsTheContentBelowTheNotch() throws {
        let l = layout(.expanded, notched, .automatic)
        let rect = try #require(l.contentRect)
        #expect(rect.minY == CGFloat(38 + 10))
        #expect(rect.size == content)
        #expect(l.rect.height == CGFloat(38 + 10 + 64 + 12))
        #expect(l.rect.width == CGFloat(260 + 32 + 2 * 15))   // content, padding, and the two top flares
        #expect(abs(rect.midX - l.rect.width / 2) < 0.5)
    }

    @Test func expandedOnAPillHangsFromTheTopEdge() {
        let l = layout(.expanded, notchless, .automatic)
        #expect(l.contentRect?.minY == 8)
        #expect(l.rect.height == CGFloat(8 + 64 + 12))
        #expect(l.rect.width == CGFloat(260 + 32))
        #expect(l.topCornerRadius == 0 && l.bottomCornerRadius == 16)
    }

    @Test func aForcedNotchOnANotchlessScreenUsesAVirtualNotch() {
        let style = IslandStyle.notch(topCornerRadius: 12, bottomCornerRadius: 18)
        let l = layout(.compact, notchless, style)
        #expect(l.look == .notch)
        #expect(l.rect.width >= 180 && l.rect.height == 32)
        #expect(l.topCornerRadius == 12 && l.bottomCornerRadius == 18)
    }

    @Test func hiddenOnANotchlessScreenIsZeroHeightWhateverTheStyle() {
        for style in styles {
            let l = layout(.hidden, notchless, style)
            #expect(l.rect.height == 0, "\(style)")
            #expect(l.rect.maxY == notchless.frame.maxY)
        }
    }

    @Test func aForcedPillOnANotchedScreenStillCoversTheNotch() {
        let l = layout(.compact, notched, .pill(cornerRadius: 14))
        #expect(l.look == .pill)
        #expect(l.rect.width >= 200 && l.rect.height >= 38)
    }

    /// The notch band in island-local coordinates: the middle `notchWidth` points.
    private func notchBand(_ l: IslandLayout, _ notchWidth: CGFloat) -> ClosedRange<CGFloat> {
        let minX = (l.rect.width - notchWidth) / 2
        return minX...(minX + notchWidth)
    }

    private func expectSlotsInsideIslandAndOutsideNotch(_ l: IslandLayout, notchWidth: CGFloat?,
                                                        sourceLocation: SourceLocation = #_sourceLocation) throws {
        let leading = try #require(l.leadingSlot, sourceLocation: sourceLocation)
        let trailing = try #require(l.trailingSlot, sourceLocation: sourceLocation)
        for slot in [leading, trailing] {
            #expect(slot.width >= 0 && slot.minX >= 0 && slot.maxX <= l.rect.width, "\(slot)", sourceLocation: sourceLocation)
        }
        #expect(leading.maxX <= trailing.minX, sourceLocation: sourceLocation)
        if let notchWidth {
            let band = notchBand(l, notchWidth)
            #expect(leading.maxX <= band.lowerBound && trailing.minX >= band.upperBound, sourceLocation: sourceLocation)
        }
    }

    @Test func aForcedPillOnANotchedScreenPutsTheSlotsBesideTheNotch() throws {
        let l = layout(.compact, notched, .pill(cornerRadius: 14))
        #expect(l.topCornerRadius == 0 && l.bottomCornerRadius == 14)
        #expect(l.rect.height == 38)
        try expectSlotsInsideIslandAndOutsideNotch(l, notchWidth: 200)
        let leading = try #require(l.leadingSlot), trailing = try #require(l.trailingSlot)
        let band = notchBand(l, 200)
        #expect(leading.maxX == band.lowerBound - 8 && trailing.minX == band.upperBound + 8)
        #expect(leading.width == slots.leading.width && trailing.width == slots.trailing.width)
        #expect(l.rect.width == CGFloat(200 + 2 * (40 + 8)))   // no flares
    }

    @Test func aForcedPillOnANotchedScreenExpandsBelowTheNotch() throws {
        let l = layout(.expanded, notched, .pill(cornerRadius: 14))
        let rect = try #require(l.contentRect)
        #expect(rect.minY == CGFloat(38 + 10))
        #expect(l.rect.height == CGFloat(38 + 10 + 64 + 12))
        #expect(rect.size == content)
    }

    @Test func aHugeSlotIsClampedAndStaysOutOfTheNotch() throws {
        var c = IslandConfiguration()
        let huge = (leading: CGSize(width: 900, height: 20), trailing: CGSize(width: 40, height: 16))
        let l = IslandGeometry.layout(state: .compact, metrics: notched, configuration: c,
                                      compactSlotSizes: huge, expandedContentSize: content)
        #expect(l.rect.width <= 756)
        try expectSlotsInsideIslandAndOutsideNotch(l, notchWidth: 200)
        #expect(l.trailingSlot?.width == 40)

        c.style = .pill(cornerRadius: 14)
        let forcedPill = IslandGeometry.layout(state: .compact, metrics: notched, configuration: c,
                                               compactSlotSizes: huge, expandedContentSize: content)
        #expect(forcedPill.rect.width <= 756)
        try expectSlotsInsideIslandAndOutsideNotch(forcedPill, notchWidth: 200)

        let wider = (leading: CGSize(width: 2000, height: 20), trailing: CGSize(width: 40, height: 16))
        let pill = IslandGeometry.layout(state: .compact, metrics: notchless, configuration: IslandConfiguration(),
                                         compactSlotSizes: wider, expandedContentSize: content)
        #expect(pill.rect.width <= notchless.frame.width / 2)
        try expectSlotsInsideIslandAndOutsideNotch(pill, notchWidth: nil)
        #expect(pill.trailingSlot?.width == 40)
        let gap = try #require(pill.trailingSlot).minX - (try #require(pill.leadingSlot)).maxX
        #expect(gap == 8)
    }

    @Test func oversizedContentIsClampedToHalfTheScreen() throws {
        let island = CGRect(origin: .zero, size: CGSize(width: notchless.frame.width / 2, height: notchless.frame.height / 2))
        let l = layout(.expanded, notchless, .automatic, content: CGSize(width: 5000, height: 5000))
        #expect(l.rect.width == notchless.frame.width / 2 && l.rect.height == notchless.frame.height / 2)
        #expect(l.rect.maxY == notchless.frame.maxY && abs(l.rect.midX - notchless.frame.midX) < 0.5)
        let rect = try #require(l.contentRect)
        #expect(island.contains(rect))
        #expect(rect.width == l.rect.width - 32 && abs(rect.midX - l.rect.width / 2) < 0.5)

        let n = layout(.expanded, notched, .automatic, content: CGSize(width: 5000, height: 5000))
        let notchRect = try #require(n.contentRect)
        #expect(CGRect(origin: .zero, size: n.rect.size).contains(notchRect))
        #expect(notchRect.width == n.rect.width - 2 * 15 - 32)
    }
}
