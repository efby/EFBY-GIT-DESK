import Foundation

public enum WorkspaceSection: String, CaseIterable, Identifiable, Sendable {
    case pending = "Pendientes"
    case staged = "Preparados"
    case history = "Historial"
    public var id: Self { self }
}
