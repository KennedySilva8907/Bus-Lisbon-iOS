import Foundation
import Observation
import BusLisbonCore

@Observable
@MainActor
final class FavouriteStops {
    private static let key = "favouriteStops"

    private(set) var ids: [String] = UserDefaults.standard.stringArray(forKey: key) ?? []

    func contains(_ id: String) -> Bool {
        ids.contains(id)
    }

    func toggle(_ id: String) {
        save(toggled(id, in: ids))
    }

    func remove(_ id: String) {
        save(ids.filter { $0 != id })
    }

    private func save(_ next: [String]) {
        ids = next
        UserDefaults.standard.set(next, forKey: Self.key)
    }
}
