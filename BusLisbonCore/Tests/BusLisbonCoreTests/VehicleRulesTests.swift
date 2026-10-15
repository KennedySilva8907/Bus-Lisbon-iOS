import Testing
@testable import BusLisbonCore

struct ReportedSecondsTests {
    @Test func keepsSecondsAsTheyAre() {
        #expect(reportedSeconds(1_789_125_473) == 1_789_125_473)
    }

    @Test func turnsMillisecondsIntoSeconds() {
        #expect(reportedSeconds(1_789_125_473_000) == 1_789_125_473)
    }

    @Test func dropsTheMillisecondsPartInsteadOfRounding() {
        #expect(reportedSeconds(1_789_125_473_999) == 1_789_125_473)
    }

    @Test func hasNothingToSayAboutAMissingOrZeroTime() {
        #expect(reportedSeconds(nil) == nil)
        #expect(reportedSeconds(0) == nil)
    }
}

private let now = 1_789_128_400

private func bus(
    id: String = "[BNA17]2547",
    lat: Double = 38.81382,
    lon: Double = -9.223133,
    timestamp: Int? = 1_789_128_390
) -> BusPosition {
    BusPosition(id: id, lat: lat, lon: lon, lineId: "2812", patternId: "2812_0_2", bearing: 256, timestamp: timestamp)
}

struct IsLiveTests {
    @Test func acceptsAFreshPosition() {
        #expect(isLive(bus(), now: now))
    }

    @Test func rejectsAPositionHoursOld() {
        #expect(!isLive(bus(timestamp: now - 7200), now: now))
    }

    @Test func rejectsAPositionHoursOldSentInMilliseconds() {
        #expect(!isLive(bus(timestamp: (now - 7200) * 1000), now: now))
    }

    @Test func acceptsAFixExactlyAtTheBoundary() {
        #expect(isLive(bus(timestamp: now - 300), now: now))
    }

    @Test func rejectsAFixOneSecondPastTheBoundary() {
        #expect(!isLive(bus(timestamp: now - 301), now: now))
    }

    @Test func skipsTheFreshnessCheckWithoutATime() {
        #expect(isLive(bus(timestamp: nil), now: now))
    }

    @Test func rejectsTheJunkRow() {
        #expect(!isLive(bus(id: "|undefined"), now: now))
        #expect(!isLive(bus(id: ""), now: now))
    }

    @Test func rejectsNullIsland() {
        #expect(!isLive(bus(lat: 0, lon: 0), now: now))
    }

    @Test func rejectsANonsenseCoordinate() {
        #expect(!isLive(bus(lat: .nan), now: now))
        #expect(!isLive(bus(lon: .infinity), now: now))
    }
}

struct KeepTheNewerTests {
    @Test func takesTheFirstPositionThereIs() {
        #expect(keepTheNewer(nil, target: "v", incoming: bus(timestamp: 100))
            == ReceivedPosition(target: "v", bus: bus(timestamp: 100)))
    }

    @Test func takesAPositionReportedLater() {
        let held = ReceivedPosition(target: "v", bus: bus(lat: 38.1, timestamp: 100))

        #expect(keepTheNewer(held, target: "v", incoming: bus(lat: 38.2, timestamp: 200)).bus.lat == 38.2)
    }

    @Test func ignoresAFrameOlderThanTheOneHeld() {
        let held = ReceivedPosition(target: "v", bus: bus(lat: 38.1, timestamp: 200))

        #expect(keepTheNewer(held, target: "v", incoming: bus(lat: 38.2, timestamp: 100)) == held)
    }

    @Test func startsOverWhenTheSelectionChanged() {
        let held = ReceivedPosition(target: "v", bus: bus(lat: 38.1, timestamp: 200))

        #expect(keepTheNewer(held, target: "other", incoming: bus(lat: 38.2, timestamp: 100))
            == ReceivedPosition(target: "other", bus: bus(lat: 38.2, timestamp: 100)))
    }

    @Test func comparesSecondsWithMillisecondsInSeconds() {
        let held = ReceivedPosition(target: "v", bus: bus(lat: 38.1, timestamp: 1_789_128_390))

        #expect(keepTheNewer(held, target: "v", incoming: bus(lat: 38.2, timestamp: 1_789_128_380_000)) == held)
        #expect(keepTheNewer(held, target: "v", incoming: bus(lat: 38.3, timestamp: 1_789_128_395_000)).bus.lat == 38.3)
    }
}
