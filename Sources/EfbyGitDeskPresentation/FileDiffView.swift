import SwiftUI
import EfbyGitDeskDomain

struct FileDiffView: View {
    let file: FileChange
    let text: String
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(file.name, systemImage: "doc.text")
                    .font(.caption.monospaced()).lineLimit(2).textSelection(.enabled)
                Spacer()
                Button("Cerrar diferencias", systemImage: "xmark", action: close)
                    .labelStyle(.iconOnly).help("Cerrar diferencias y volver a la lista de archivos")
            }.padding(12)
            Divider()
            TextPreview(text: text).frame(maxWidth: .infinity, maxHeight: .infinity)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
