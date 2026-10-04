// DynamicLanding — SizeReader.swift
import SwiftUI

/// Reports a view's laid-out size to the model, so the shape can follow the content.
struct SizeReader: ViewModifier {
    let onChange: @MainActor (CGSize) -> Void
    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGSize.self, of: \.size) { size in onChange(size) }
    }
}

extension View {
    func readSize(_ onChange: @escaping @MainActor (CGSize) -> Void) -> some View {
        modifier(SizeReader(onChange: onChange))
    }
}
