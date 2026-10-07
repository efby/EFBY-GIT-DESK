import SwiftUI
import AppKit

struct RepositoryWorkArea: View {
    @Bindable var model: DeskModel
    var body: some View {
        VStack(spacing: 0) {
            WorkspaceTabs(model: model)
            Divider()
            HSplitView {
                HistoryPane(model: model).frame(minWidth: 370)
                DiffPane(model: model).frame(minWidth: 340, idealWidth: model.detailWidth)
                    .background(PanelWidthObserver { model.detailWidth = $0; model.persistLayout() })
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}
