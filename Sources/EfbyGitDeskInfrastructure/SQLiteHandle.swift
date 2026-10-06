import CSQLite

// The handle is never exposed outside SQLiteRegistry. The actor serializes all
// statements; its final owner releases the connection after those uses end.
final class SQLiteHandle: @unchecked Sendable {
    let pointer: OpaquePointer
    init(_ pointer: OpaquePointer) { self.pointer = pointer }
    deinit { sqlite3_close(pointer) }
}
