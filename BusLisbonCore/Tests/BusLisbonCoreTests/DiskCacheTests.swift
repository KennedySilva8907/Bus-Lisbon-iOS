import Foundation
import Testing
@testable import BusLisbonCore

private struct Offline: Error {}

private let stopsJSON = #"[{"id":"010001","name":"Escola","lat":"38.754244","lon":"-8.959557"}]"#

private let offline = BusLisbonAPI { _, _ in throw Offline() }
private let online = BusLisbonAPI { _, _ in (Data(stopsJSON.utf8), 200) }

private func freshCache() -> DiskCache {
    DiskCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
}

private let day: TimeInterval = 86_400

struct DiskCacheTests {
    @Test func givesBackWhatWasSaved() throws {
        let cache = freshCache()

        try cache.save(["a", "b"], as: "letters")

        #expect(cache.load([String].self, key: "letters", maxAge: day) == ["a", "b"])
    }

    @Test func refusesACopyOlderThanAsked() throws {
        let cache = freshCache()
        let saved = Date(timeIntervalSince1970: 1_789_000_000)

        try cache.save(["a"], as: "letters", now: saved)

        #expect(cache.load([String].self, key: "letters", maxAge: day, now: saved.addingTimeInterval(day + 1)) == nil)
        #expect(cache.load([String].self, key: "letters", maxAge: nil, now: saved.addingTimeInterval(day + 1)) == ["a"])
    }

    @Test func copesWithAKeyFullOfBrackets() throws {
        let cache = freshCache()

        try cache.save([1], as: "route-[BNA17]2812_0_2|1")

        #expect(cache.load([Int].self, key: "route-[BNA17]2812_0_2|1", maxAge: nil) == [1])
    }
}

struct LoadStopsTests {
    @Test func usesTheNetworkWhenThereIsNoCopy() async {
        let cache = freshCache()

        let stops = await loadStops(cache: cache, api: online)

        #expect(stops?.map(\.id) == ["010001"])
        #expect(cache.load([Stop].self, key: "stops", maxAge: day)?.map(\.id) == ["010001"])
    }

    @Test func doesNotNeedTheNetworkWhileTheCopyIsFresh() async throws {
        let cache = freshCache()
        try cache.save([Stop(id: "060161", name: "Estr. Desvio", lat: 38.77, lon: -9.15)], as: "stops")

        let stops = await loadStops(cache: cache, api: offline)

        #expect(stops?.map(\.id) == ["060161"])
    }

    @Test func fallsBackToAStaleCopyWhenOffline() async throws {
        let cache = freshCache()
        let now = Date(timeIntervalSince1970: 1_789_000_000)
        try cache.save([Stop(id: "060161", name: "Estr. Desvio", lat: 38.77, lon: -9.15)], as: "stops", now: now.addingTimeInterval(-3 * day))

        let stops = await loadStops(cache: cache, api: offline, now: now)

        #expect(stops?.map(\.id) == ["060161"])
    }

    @Test func givesNothingWhenOfflineWithNoCopy() async {
        #expect(await loadStops(cache: freshCache(), api: offline) == nil)
    }
}
