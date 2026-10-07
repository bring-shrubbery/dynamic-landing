// DynamicLanding — IslandMeasurementTests.swift
import AppKit
import SwiftUI
import Testing
@testable import DynamicLanding

/// The island animates a state change from the content's measured size, so that size must be
/// known before the animation starts. A layout pass of the hosting view is what measures it.
@MainActor
struct IslandMeasurementTests {
    private let metrics = ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 1440, height: 900), notchSize: nil, menuBarHeight: 24)

    private func host(_ model: IslandModel) -> NSHostingView<IslandView> {
        let hosting = NSHostingView(rootView: IslandView(model: model))
        hosting.frame = CGRect(x: 0, y: 0, width: 720, height: 450)
        hosting.layoutSubtreeIfNeeded()
        return hosting
    }

    @Test func aLayoutPassMeasuresNewContentAtOnce() {
        let model = IslandModel(configuration: IslandConfiguration(), metrics: metrics)
        let hosting = host(model)
        model.setExpanded(AnyView(Color.red.frame(width: 200, height: 40)))
        #expect(model.contentSize == .zero)
        hosting.layoutSubtreeIfNeeded()
        #expect(model.contentSize == CGSize(width: 200, height: 40))
    }

    @Test func theExpandedLayoutIsFinalBeforeTheStateChanges() {
        let model = IslandModel(configuration: IslandConfiguration(), metrics: metrics)
        let hosting = host(model)
        model.setCompact(leading: AnyView(Color.red.frame(width: 30, height: 14)),
                         trailing: AnyView(Color.red.frame(width: 40, height: 14)))
        model.setExpanded(AnyView(Color.red.frame(width: 260, height: 60)))
        hosting.layoutSubtreeIfNeeded()
        // Measured while hidden: the state change that follows moves straight to this size.
        model.setState(.expanded)
        let target = model.layout
        hosting.layoutSubtreeIfNeeded()
        #expect(model.layout == target)
        #expect(model.leadingSize == CGSize(width: 30, height: 14))
        #expect(model.trailingSize == CGSize(width: 40, height: 14))
    }
}
