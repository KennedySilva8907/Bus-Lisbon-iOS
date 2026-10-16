import Foundation
import Observation
import BusLisbonCore

struct FollowTarget: Hashable {
    let vehicleId: String
    let tripId: String
    let lineId: String
    let patternId: String
}

struct FollowRun: Hashable {
    let target: FollowTarget?
    let wake: Int
}

@Observable
@MainActor
final class FollowModel {
    private(set) var state = FollowState()
    private(set) var route: Route?

    func run(_ target: FollowTarget) async {
        state = FollowState()
        route = nil
        var routeAsked = false

        while !Task.isCancelled {
            let incoming = await position(of: target)
            state = advance(state, target: target.vehicleId, incoming: incoming, now: Int(Date().timeIntervalSince1970))

            if !routeAsked {
                routeAsked = true
                route = await loadRoute(patternId: target.patternId, cache: AppServices.cache, api: AppServices.api)
            }

            try? await Task.sleep(for: .seconds(8))
        }
    }

    func stop() {
        state = FollowState()
        route = nil
    }

    private func position(of target: FollowTarget) async -> BusPosition? {
        do {
            return try await AppServices.api.vehicle(id: target.vehicleId, tripId: target.tripId, lineId: target.lineId)
        } catch {
            let fleet = (try? await AppServices.api.fleet()) ?? []
            return findBus(in: fleet, id: target.vehicleId, lineId: target.lineId)
        }
    }
}
