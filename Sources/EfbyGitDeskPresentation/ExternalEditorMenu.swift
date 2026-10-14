import SwiftUI

struct ExternalEditorMenuItems: View {
    let path: String
    var open: (ExternalEditor) -> Void

    private var editors: [ExternalEditor] { ExternalEditorCatalog.installedEditors() }

    var body: some View {
        if editors.count == 1, let editor = editors.first {
            Button("Abrir en \(editor.displayName)", systemImage: "chevron.left.forwardslash.chevron.right") {
                open(editor)
            }
        } else if editors.count > 1 {
            Menu("Abrir en editor", systemImage: "chevron.left.forwardslash.chevron.right") {
                ForEach(editors) { editor in
                    Button(editor.displayName) { open(editor) }
                }
            }
        }
    }
}
