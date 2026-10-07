import SwiftUI

/// Keep the repository mounted while the comparison covers its entire app area.
struct ComparisonWorkspaceLayer<Content: View>: View {
    @Bindable var model: DeskModel
    let content: Content
    init(model: DeskModel, @ViewBuilder content: () -> Content) {
        self.model = model; self.content = content()
    }
    var body: some View {
        let file = model.files.first { $0.id == model.selectedFile }
        ZStack {
            content.opacity(file == nil ? 1 : 0)
                .disabled(file != nil).allowsHitTesting(file == nil).accessibilityHidden(file != nil)
            if let file {
                PersistentSplitView(width: $model.detailWidth, anchoredLeading: false,
                                    minimum: 340, maximum: .greatestFiniteMagnitude, otherMinimum: 640) {
                    FileDiffView(model: model, file: file).id(file.id)
                } second: {
                    DiffPane(model: model)
                }.background(ComparisonFocusAnchor()).zIndex(1)
                    .onChange(of: model.detailWidth) { _, _ in model.persistLayout() }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
