import Foundation
import EfbyGitDeskDomain

public enum GraphLayout {
    public static func make(_ commits: [Commit]) -> [String: GraphRow] {
        var lanes: [String] = []
        var rows: [String: GraphRow] = [:]
        for commit in commits {
            if !lanes.contains(commit.oid) { lanes.insert(commit.oid, at: 0) }
            let before = lanes
            let lane = lanes.firstIndex(of: commit.oid)!
            lanes.remove(at: lane)
            for (offset, parent) in commit.parents.enumerated() where !lanes.contains(parent) {
                lanes.insert(parent, at: min(lane + offset, lanes.count))
            }
            rows[commit.oid] = GraphRow(lane: lane, before: before, after: lanes, parents: commit.parents)
        }
        return rows
    }
}
