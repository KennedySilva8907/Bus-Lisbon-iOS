import Testing
@testable import BusLisbonCore

private let now = 1_789_128_400
private let target = "[BNA17]2547"

private func bus(_ timestamp: Int?, lat: Double = 38.8) -> BusPosition {
    BusPosition(id: target, lat: lat, lon: -9.22, lineId: "2812", patternId: "2812_0_2", bearing: nil, timestamp: timestamp)
}

struct FollowTests {
    @Test func showsAFreshPosition() {
        let state = advance(FollowState(), target: target, incoming: bus(now - 10), now: now)

        #expect(state.shown == bus(now - 10))
        #expect(!state.noRecentPosition)
    }

    @Test func ignoresAnOlderPosition() {
        let first = advance(FollowState(), target: target, incoming: bus(now - 10, lat: 38.9), now: now)

        let second = advance(first, target: target, incoming: bus(now - 40, lat: 38.1), now: now)

        #expect(second.shown?.lat == 38.9)
    }

    @Test func keepsTheLastPositionWhenNothingArrives() {
        let first = advance(FollowState(), target: target, incoming: bus(now - 10), now: now)

        let second = advance(first, target: target, incoming: nil, now: now + 60)

        #expect(second.shown == bus(now - 10))
    }

    @Test func dropsAPositionOlderThanFiveMinutes() {
        let first = advance(FollowState(), target: target, incoming: bus(now - 10), now: now)

        let later = advance(first, target: target, incoming: nil, now: now + 300)

        #expect(later.shown == nil)
        #expect(later.noRecentPosition)
    }

    @Test func saysThereIsNoRecentPositionForABusNeverSeen() {
        let state = advance(FollowState(), target: target, incoming: nil, now: now)

        #expect(state.shown == nil)
        #expect(state.noRecentPosition)
    }

    @Test func ignoresAStalePositionArriving() {
        let state = advance(FollowState(), target: target, incoming: bus(now - 600), now: now)

        #expect(state.shown == nil)
    }

    @Test func comparesABackendSecondWithAFleetMillisecond() {
        let fromBackend = advance(FollowState(), target: target, incoming: bus(now - 10, lat: 38.9), now: now)

        let olderFleet = advance(fromBackend, target: target, incoming: bus((now - 40) * 1000, lat: 38.1), now: now)
        let newerFleet = advance(fromBackend, target: target, incoming: bus((now - 5) * 1000, lat: 38.5), now: now)

        #expect(olderFleet.shown?.lat == 38.9)
        #expect(newerFleet.shown?.lat == 38.5)
    }
}
