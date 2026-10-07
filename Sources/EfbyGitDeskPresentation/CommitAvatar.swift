import SwiftUI

/// A provider-supplied avatar is optional; local Git metadata never supplies one.
struct CommitAvatar: View {
    let author: String
    let url: URL?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(Color.teal.opacity(0.18))
            Text(initials).font(.headline).foregroundStyle(.teal)
            if let url {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: { Color.clear }
            }
        }.frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 5))
            .accessibilityHidden(true)
    }
    private var initials: String {
        let words = author.split(whereSeparator: \.isWhitespace)
        return words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}
