import SwiftUI

struct ComparisonFocusAnchor: NSViewRepresentable {
    func makeNSView(context: Context) -> ComparisonFocusView { ComparisonFocusView() }
    func updateNSView(_ view: ComparisonFocusView, context: Context) {}
    static func dismantleNSView(_ view: ComparisonFocusView, coordinator: ()) { view.restoreFocus() }
}
