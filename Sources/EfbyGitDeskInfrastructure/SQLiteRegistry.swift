import Foundation
import CSQLite
import EfbyGitDeskApplication
import EfbyGitDeskDomain

public actor SQLiteRegistry: RegistryPort {
    private let handle: SQLiteHandle
    private var database: OpaquePointer? { handle.pointer }
    public init(path: String) throws {
        let folder = URL(fileURLWithPath: path).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var connection: OpaquePointer?
        let status = sqlite3_open(path, &connection)
        guard status == SQLITE_OK, let connection else {
            sqlite3_close(connection); throw DeskError("No se pudo abrir el catálogo local.")
        }
        handle = SQLiteHandle(connection)
        var versionQuery: OpaquePointer?
        guard sqlite3_prepare_v2(connection, "PRAGMA user_version", -1, &versionQuery, nil) == SQLITE_OK else {
            throw DeskError("No se pudo leer la versión del catálogo.")
        }
        let state = sqlite3_step(versionQuery)
        let version = sqlite3_column_int(versionQuery, 0)
        sqlite3_finalize(versionQuery)
        guard state == SQLITE_ROW, version <= 1 else {
            throw DeskError("Este catálogo pertenece a una versión más reciente de EfbyGitDesk.")
        }
        let schema = """
        PRAGMA journal_mode=WAL;
        CREATE TABLE IF NOT EXISTS repositories(id TEXT PRIMARY KEY, value BLOB NOT NULL);
        CREATE TABLE IF NOT EXISTS profiles(id TEXT PRIMARY KEY, value BLOB NOT NULL);
        CREATE TABLE IF NOT EXISTS preferences(id TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS operations(id TEXT PRIMARY KEY, phase TEXT, repository TEXT, recovery TEXT, updated REAL);
        PRAGMA user_version=1;
        UPDATE operations SET phase='interrupted' WHERE phase IN ('running','prepared');
        """
        guard sqlite3_exec(connection, schema, nil, nil, nil) == SQLITE_OK else { throw DeskError("No se pudo preparar el catálogo.") }
    }
    public func repositories() throws -> [Repository] {
        try rows("SELECT value FROM repositories").map { try JSONDecoder().decode(Repository.self, from: $0) }
            .sorted { $0.lastOpened > $1.lastOpened }
    }
    public func save(_ repository: Repository) throws {
        try write("INSERT OR REPLACE INTO repositories VALUES(?,?)", values: [Data(repository.id.utf8), try JSONEncoder().encode(repository)])
    }
    public func remove(id: String) throws { try write("DELETE FROM repositories WHERE id=?", values: [Data(id.utf8)]) }
    public func profiles() throws -> [ConnectionProfile] {
        try rows("SELECT value FROM profiles").map { try JSONDecoder().decode(ConnectionProfile.self, from: $0) }
    }
    public func saveProfile(_ profile: ConnectionProfile) throws {
        try write("INSERT OR REPLACE INTO profiles VALUES(?,?)", values: [Data(profile.id.utf8), try JSONEncoder().encode(profile)])
    }
    public func removeProfile(id: String) throws { try write("DELETE FROM profiles WHERE id=?", values: [Data(id.utf8)]) }
    public func preference(_ key: String) throws -> String? {
        try rows("SELECT value FROM preferences WHERE id=?", values: [Data(key.utf8)]).first.map { String(decoding: $0, as: UTF8.self) }
    }
    public func setPreference(_ key: String, value: String) throws {
        try write("INSERT OR REPLACE INTO preferences VALUES(?,?)", values: [Data(key.utf8), Data(value.utf8)])
    }
    public func record(operation: String, phase: String, repository: String, recovery: String?) throws {
        try write("INSERT OR REPLACE INTO operations VALUES(?,?,?,?,?)", values: [
            Data(operation.utf8), Data(phase.utf8), Data(repository.utf8),
            Data((recovery ?? "").utf8), Data(String(Date.now.timeIntervalSince1970).utf8)
        ])
    }
    private func prepare(_ sql: String, values: [Data]) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw DeskError("El catálogo no pudo preparar una consulta.")
        }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, value) in values.enumerated() {
            _ = value.withUnsafeBytes { sqlite3_bind_text(statement, Int32(index + 1), $0.baseAddress?.assumingMemoryBound(to: CChar.self), Int32(value.count), transient) }
        }
        return statement
    }
    private func write(_ sql: String, values: [Data]) throws {
        let statement = try prepare(sql, values: values)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw DeskError("No se pudo guardar el catálogo local.") }
    }
    private func rows(_ sql: String, values: [Data] = []) throws -> [Data] {
        let statement = try prepare(sql, values: values)
        defer { sqlite3_finalize(statement) }
        var result: [Data] = []
        var state = sqlite3_step(statement)
        while state == SQLITE_ROW {
            if let bytes = sqlite3_column_blob(statement, 0) {
                result.append(Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0))))
            } else { result.append(Data()) }
            state = sqlite3_step(statement)
        }
        guard state == SQLITE_DONE else { throw DeskError("No se pudo leer el catálogo local.") }
        return result
    }
}
