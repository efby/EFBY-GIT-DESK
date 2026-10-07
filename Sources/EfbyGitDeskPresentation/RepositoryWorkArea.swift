import SwiftUI
import AppKit

struct RepositoryWorkArea: View {
    @Bindable var model: DeskModel
    var body: some View {
        VStack(spacing: 0) {
            WorkspaceTabs(model: model)
            Divider()
            PersistentSplitView(width: $model.detailWidth, anchoredLeading: false, minimum: 340, maximum: .greatestFiniteMagnitude, otherMinimum: 370) {
                HistoryPane(model: model)
            } second: {
                DiffPane(model: model)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            .onChange(of: model.detailWidth) { _, _ in model.persistLayout() }
    }
}
