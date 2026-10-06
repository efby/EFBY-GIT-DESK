import Foundation

actor OperationGate {
    private var held: Set<String> = []
    private var waiting: [String: [CheckedContinuation<Void, Never>]] = [:]
    func acquire(_ key: String) async {
        if held.insert(key).inserted { return }
        await withCheckedContinuation { continuation in
            waiting[key, default: []].append(continuation)
        }
    }
    func release(_ key: String) {
        if var list = waiting[key], !list.isEmpty {
            let next = list.removeFirst()
            waiting[key] = list
            next.resume()
        } else {
            held.remove(key)
            waiting.removeValue(forKey: key)
        }
    }
}
