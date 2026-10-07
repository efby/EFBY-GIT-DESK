import AppKit
import SwiftUI

/// Retains the hosted views while the native divider changes their sizes.
struct PersistentSplitView<First: View, Second: View>: NSViewRepresentable {
    @Binding var width: Double
    let anchoredLeading: Bool
    let minimum: Double
    let maximum: Double
    let otherMinimum: Double
    @ViewBuilder var first: () -> First
    @ViewBuilder var second: () -> Second

    func makeNSView(context: Context) -> PersistentSplitContainer {
        let split = PersistentSplitContainer()
        let left = NSHostingView(rootView: panel(first()))
        let right = NSHostingView(rootView: panel(second()))
        left.appearance = NSAppearance(named: .darkAqua); right.appearance = left.appearance
        left.sizingOptions = []; right.sizingOptions = []
        split.addArrangedSubview(left); split.addArrangedSubview(right)
        configure(split)
        return split
    }
    func updateNSView(_ split: PersistentSplitContainer, context: Context) {
        (split.arrangedSubviews[0] as? NSHostingView<AnyView>)?.rootView = panel(first())
        (split.arrangedSubviews[1] as? NSHostingView<AnyView>)?.rootView = panel(second())
        configure(split)
    }
    private func panel<Content: View>(_ content: Content) -> AnyView {
        AnyView(content.preferredColorScheme(.dark).tint(.teal).background(Color(nsColor: .windowBackgroundColor)))
    }
    private func configure(_ split: PersistentSplitContainer) {
        split.anchoredLeading = anchoredLeading
        split.minimum = minimum; split.maximum = maximum; split.otherMinimum = otherMinimum
        split.changed = { width = $0 }
        if split.preferredWidth != width {
            split.preferredWidth = width
            split.applyPreferredWidth()
        }
    }
}
