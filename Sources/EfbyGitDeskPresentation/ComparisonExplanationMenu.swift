import SwiftUI

struct ComparisonExplanationMenu: View {
    let model: DeskModel

    var body: some View {
        if model.canExplainComparisonInCursor || model.canExplainComparisonInClaude {
            Menu("Explicar cambios", systemImage: "sparkles") {
                if model.canExplainComparisonInCursor {
                    Button("En Cursor") { model.explainComparisonInCursor() }
                }
                if model.canExplainComparisonInClaude {
                    Button("En Claude") { model.explainComparisonInClaude() }
                }
            }
            .accessibilityIdentifier("explainComparisonMenu")
            .help("Elige dónde revisar la comparación A → B. El mensaje se prepara para que lo confirmes antes de enviarlo.")
        }
    }
}
