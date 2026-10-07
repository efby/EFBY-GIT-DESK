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
                FileDiffView(model: model, file: file).id(file.id)
                    .background(ComparisonFocusAnchor()).zIndex(1)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
