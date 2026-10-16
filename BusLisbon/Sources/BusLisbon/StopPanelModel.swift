import Foundation
import Observation
import BusLisbonCore

@Observable
@MainActor
final class StopPanelModel {
    private(set) var arrivals: [Arrival] = []
    private(set) var loaded = false
    private(set) var failed = false
    private(set) var updatedAt: Date?

    func run(stopId: String) async {
        arrivals = []
        loaded = false
        failed = false
        updatedAt = nil

        while !Task.isCancelled {
            do {
                arrivals = toArrivals(try await AppServices.api.board(stopId: stopId))
                updatedAt = Date()
                failed = false
                await ArrivalAlerts.shared.refresh(stopId: stopId, arrivals: arrivals, now: Int(Date().timeIntervalSince1970))
            } catch {
                failed = true
            }
            loaded = true
            try? await Task.sleep(for: .seconds(15))
        }
    }
}
