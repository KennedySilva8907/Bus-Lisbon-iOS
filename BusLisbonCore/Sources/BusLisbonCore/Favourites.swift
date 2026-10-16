import Foundation

public func toggled(_ id: String, in ids: [String]) -> [String] {
    ids.contains(id) ? ids.filter { $0 != id } : ids + [id]
}

extension StopSearchIndex {
    public func stops(withIds ids: [String]) -> [Stop] {
        ids.compactMap { byId[$0] }
    }
}
