import Foundation
import EfbyGitDeskDomain

/// Reads raw blobs; never invokes filters, textconv, external diffs or lazy fetch.
struct GitComparisonReader: Sendable {
    let repository: Repository
    let read: @Sendable ([String], Int, Bool) async throws -> ProcessResult
    private let limit = 2_000_000

    func load(context: DiffContext, file: FileChange, patch: String) async throws -> FileComparison {
        guard let path = file.utf8Path,
              let oldPath = String(data: file.oldPath ?? file.path, encoding: .utf8) else {
            return FileComparison(before: nil, after: nil, beforeLabel: "Documento 1", afterLabel: "Documento 2", patch: patch,
                                  notice: "La ruta no es UTF-8; se conserva en el inventario.")
        }
        let before: String?, after: String?, beforeLabel: String, afterLabel: String
        switch context {
        case .commits(let pair):
            beforeLabel = pair.base; afterLabel = pair.target
            before = try await tree(pair.base, path: oldPath)
            after = try await tree(pair.target, path: path)
        case .commit(let oid, let parent):
            let result = try await read(["show", "-s", "--format=%P", oid], 4096, false)
            let parents = result.text.split(whereSeparator: \.isWhitespace).map(String.init)
            if parents.isEmpty { before = ""; beforeLabel = "Árbol vacío" }
            else {
                guard parents.indices.contains(parent) else { throw DeskError("Padre del commit no válido.") }
                beforeLabel = parents[parent]
                before = try await tree(parents[parent], path: oldPath)
            }
            afterLabel = oid; after = try await tree(oid, path: path)
        case .staged:
            let head = try await read(["rev-parse", "--verify", "--quiet", "HEAD"], 4096, true)
            beforeLabel = "HEAD"; afterLabel = "Índice"
            before = head.status == 0 ? try await tree(head.text.trimmingCharacters(in: .whitespacesAndNewlines), path: oldPath) : ""
            after = try await index(path)
        case .working:
            beforeLabel = "Índice"; afterLabel = "Área de trabajo"
            before = try await index(path)
            after = try working(path)
        }
        var notices = patch.components(separatedBy: "\n").filter {
            $0.hasPrefix("old mode ") || $0.hasPrefix("new mode ") || $0.hasPrefix("new file mode ") || $0.hasPrefix("deleted file mode ")
        }
        if before == nil || after == nil {
            notices.append("Comparación textual no disponible: contenido binario, no UTF-8, submódulo, conflicto o archivo mayor de 2 MB. Se conserva el resumen de Git.")
        }
        if (before ?? "").hasPrefix("version https://git-lfs.github.com/spec/v1") || (after ?? "").hasPrefix("version https://git-lfs.github.com/spec/v1") { notices.append("Git LFS: se muestran los punteros, sin descargar contenido.") }
        if patch.contains("mode 120000") { notices.append("Enlace simbólico: se muestra el destino textual, sin leerlo.") }
        if patch.contains("[Diff truncado") { notices.append("El diff supera 2 MB; no se presenta una alineación incompleta como comparación completa.") }
        return FileComparison(before: before, after: after, beforeLabel: beforeLabel, afterLabel: afterLabel,
                              patch: patch, notice: notices.joined(separator: "\n"))
    }

    private func tree(_ oid: String, path: String) async throws -> String? {
        guard ComparisonPair.validOID(oid) else { throw DeskError("OID no válido.") }
        let result = try await read(["ls-tree", "-z", oid, "--", path], limit, false)
        guard !result.truncated else { throw DeskError("La consulta del archivo supera el límite del visor.") }
        for record in result.output.split(separator: 0) {
            guard let tab = record.firstIndex(of: 9), Data(record[record.index(after: tab)...]) == Data(path.utf8) else { continue }
            let fields = String(decoding: record[..<tab], as: UTF8.self).split(separator: " ")
            guard fields.count == 3, fields[1] == "blob" else { return nil }
            return try await blob(String(fields[2]))
        }
        return "" // The file does not exist in this tree (addition/deletion).
    }

    private func index(_ path: String) async throws -> String? {
        let result = try await read(["ls-files", "--stage", "-z", "--", path], limit, false)
        guard !result.truncated else { throw DeskError("La consulta del índice supera el límite del visor.") }
        for record in result.output.split(separator: 0) {
            guard let tab = record.firstIndex(of: 9), Data(record[record.index(after: tab)...]) == Data(path.utf8) else { continue }
            let fields = String(decoding: record[..<tab], as: UTF8.self).split(separator: " ")
            guard fields.count == 3, fields[2] == "0", fields[0] != "160000" else { return nil }
            return try await blob(String(fields[1]))
        }
        return ""
    }

    private func blob(_ oid: String) async throws -> String? {
        guard ComparisonPair.validOID(oid) else { throw DeskError("Objeto no válido.") }
        let size = try await read(["cat-file", "-s", oid], 4096, false)
        guard let count = Int(size.text.trimmingCharacters(in: .whitespacesAndNewlines)), count <= limit else { return nil }
        let result = try await read(["cat-file", "blob", oid], limit, false)
        guard !result.truncated, !result.output.contains(0) else { return nil }
        return String(data: result.output, encoding: .utf8)
    }

    private func working(_ path: String) throws -> String? {
        let url = URL(fileURLWithPath: repository.path).appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: url.path) || (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil else { return "" }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if attributes[.type] as? FileAttributeType == .typeSymbolicLink {
            return try FileManager.default.destinationOfSymbolicLink(atPath: url.path)
        }
        guard url.resolvingSymlinksInPath().path.hasPrefix(repository.path + "/"),
              attributes[.type] as? FileAttributeType == .typeRegular,
              (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= limit else { return nil }
        let data = try Data(contentsOf: url)
        guard data.count <= limit, !data.contains(0) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
