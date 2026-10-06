import SwiftUI

struct PanelWidthObserver: View {
    var changed: (Double) -> Void
    var body: some View {
        GeometryReader { proxy in
            Color.clear.onChange(of: proxy.size.width) { _, width in
                if width > 0 { changed(width) }
            }
        }
    }
}
