import SwiftUI
import EfbyGitDeskDomain

struct DiffDocumentHeader: View {
    let title: String
    let revision: String
    let path: String
    let text: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.bold())
            Text(ComparisonPair.validOID(revision) ? String(revision.prefix(12)) : revision)
                .font(.caption.monospaced()).textSelection(.enabled).help(revision)
            Text(path).font(.caption2).lineLimit(1).truncationMode(.middle).help(path)
            if let text, !text.isEmpty && text.utf8.last != 10 {
                Text("Sin salto de línea final").font(.caption2).foregroundStyle(.secondary)
            }
        }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
    }
}
