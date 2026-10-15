// DynamicLanding — IslandShapeTests.swift
import SwiftUI
import Testing
@testable import DynamicLanding

struct IslandShapeTests {
    @Test func theNotchShapeFlaresAtTheTopAndStaysInsideItsRect() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 80)
        let path = IslandShape(look: .notch, topCornerRadius: 15, bottomCornerRadius: 20).path(in: rect)
        let bounds = path.boundingRect
        #expect(bounds.minX >= -0.01 && bounds.maxX <= 300.01 && bounds.minY >= -0.01 && bounds.maxY <= 80.01)
        #expect(abs(bounds.width - 300) < 0.01)
        // The top edge spans the full width (the flares meet the menu bar); the body is narrower.
        // The flares leave the top edge tangentially, so probe inside the flare band (x < 15,
        // outside the body) rather than at the very corner.
        #expect(path.contains(CGPoint(x: 6, y: 0.5)) && path.contains(CGPoint(x: 294, y: 0.5)))
        #expect(!path.contains(CGPoint(x: 6, y: 14)) && path.contains(CGPoint(x: 16, y: 14)))
        #expect(!path.contains(CGPoint(x: 1, y: 40)) && path.contains(CGPoint(x: 150, y: 40)))
    }

    @Test func thePillShapeIsFlatOnTopAndRoundedBelow() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 60)
        let path = IslandShape(look: .pill, topCornerRadius: 0, bottomCornerRadius: 16).path(in: rect)
        #expect(path.contains(CGPoint(x: 0.5, y: 0.5)) && path.contains(CGPoint(x: 199.5, y: 0.5)))
        #expect(!path.contains(CGPoint(x: 1, y: 59)) && path.contains(CGPoint(x: 100, y: 59)))
        #expect(path.contains(CGPoint(x: 1, y: 30)) && path.contains(CGPoint(x: 199, y: 30)))
    }

    @Test func thePillsFilletsRoundTheJoinWithTheTopEdge() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 60)
        let path = IslandShape(look: .pill, topCornerRadius: 6, bottomCornerRadius: 16).path(in: rect)
        // The top row spans the full width, meeting the edge; the body below the fillets is
        // narrower by a fillet on each side, and the fillet's own corner is outside the shape.
        #expect(path.contains(CGPoint(x: 2, y: 0.5)) && path.contains(CGPoint(x: 198, y: 0.5)))
        #expect(!path.contains(CGPoint(x: 1, y: 5)) && path.contains(CGPoint(x: 7, y: 5)))
        #expect(!path.contains(CGPoint(x: 3, y: 30)) && path.contains(CGPoint(x: 7, y: 30)) && !path.contains(CGPoint(x: 197, y: 30)))
        #expect(!path.contains(CGPoint(x: 7, y: 59.5)) && path.contains(CGPoint(x: 100, y: 59)))
        let bounds = path.boundingRect
        #expect(abs(bounds.width - 200) < 0.01 && abs(bounds.height - 60) < 0.01)
    }

    @MainActor @Test func theModelLaysOutFromItsInputs() {
        let metrics = ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), notchSize: CGSize(width: 200, height: 38), menuBarHeight: 38)
        let model = IslandModel(configuration: IslandConfiguration(), metrics: metrics)
        #expect(model.layout.rect == metrics.notchRect)
        model.contentSize = CGSize(width: 100, height: 50)
        model.setState(.expanded)
        #expect(model.layout.rect.height == CGFloat(38 + 10 + 50 + 12))
        #expect(model.layout.rect.maxY == 982)
    }

    @MainActor @Test func replacingContentInTheSameStateKeepsItsIdentity() {
        let metrics = ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), notchSize: CGSize(width: 200, height: 38), menuBarHeight: 38)
        let model = IslandModel(configuration: IslandConfiguration(), metrics: metrics)
        model.setState(.expanded)
        let generation = model.contentGeneration
        model.setExpanded(AnyView(Text("0:01")))
        model.setExpanded(AnyView(Text("0:02")))
        #expect(model.contentGeneration == generation)
        model.setState(.expanded)
        #expect(model.contentGeneration == generation)
        model.setState(.compact)
        let compactGeneration = model.contentGeneration
        #expect(compactGeneration != generation)
        model.setCompact(leading: AnyView(Text("a")), trailing: AnyView(Text("b")))
        #expect(model.contentGeneration == compactGeneration)
        model.setState(.expanded)
        #expect(model.contentGeneration != compactGeneration)
    }

    @MainActor @Test func clearingContentResetsViewsAndSizes() {
        let metrics = ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), notchSize: CGSize(width: 200, height: 38), menuBarHeight: 38)
        let model = IslandModel(configuration: IslandConfiguration(), metrics: metrics)
        model.setCompact(leading: AnyView(Text("a")), trailing: AnyView(Text("b")))
        model.setExpanded(AnyView(Text("c")))
        model.leadingSize = CGSize(width: 10, height: 10)
        model.trailingSize = CGSize(width: 20, height: 10)
        model.contentSize = CGSize(width: 100, height: 50)
        model.clearContent()
        #expect(model.leadingSize == .zero && model.trailingSize == .zero && model.contentSize == .zero)
        #expect(!model.hasContent)
    }
}
