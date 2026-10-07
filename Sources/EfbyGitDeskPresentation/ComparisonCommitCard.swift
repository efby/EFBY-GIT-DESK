import SwiftUI
import AppKit
import EfbyGitDeskDomain

struct ComparisonCommitCard: View {
    let commit: Commit
    let revisionLabel: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CommitAvatar(author: commit.author, url: commit.avatarURL)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(commit.message).font(.body).lineLimit(1).help(commit.message)
                    Spacer(minLength: 4)
                    Button(action: copySHA) {
                        Text(commit.shortOID).font(.body.monospaced().bold())
                    }.buttonStyle(.plain).help("Copiar SHA completo")
                        .accessibilityLabel("Copiar SHA completo: \(commit.oid)")
                }
                Text("\(formattedDate) · \(commit.author)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Text(revisionLabel).font(.caption2.bold()).foregroundStyle(.teal)
            }
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.45))
            .accessibilityElement(children: .contain)
    }

    private var formattedDate: String {
        guard let date = ISO8601DateFormatter().date(from: commit.date) else { return commit.date }
        return date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }
    private func copySHA() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(commit.oid, forType: .string)
    }
}
