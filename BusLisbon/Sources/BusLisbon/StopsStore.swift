import Foundation
import Observation
import BusLisbonCore

@Observable
@MainActor
final class StopsStore {
    private(set) var stops: [Stop]?
    private(set) var failed = false

    func load() async {
        failed = false
        async let woken: Void = AppServices.api.wake()
        let loaded = await loadStops(cache: AppServices.cache, api: AppServices.api)
        stops = loaded ?? stops
        failed = loaded == nil
        await woken
    }
}
