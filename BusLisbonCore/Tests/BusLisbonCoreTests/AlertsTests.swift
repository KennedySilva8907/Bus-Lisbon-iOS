import Testing
@testable import BusLisbonCore

private let now = 1_787_340_000

private func coming(at arrivalUnix: Int) -> Arrival {
    Arrival(
        tripId: "t",
        lineId: "2812",
        patternId: "[BNA17]2812_0_2",
        headsign: "Caneças",
        estimatedUnix: arrivalUnix,
        scheduledUnix: now,
        observedUnix: nil,
        wentByUnix: nil,
        tripRunning: true,
        vehicleId: "2602"
    )
}

struct AlertsTests {
    @Test func leavesAMinuteOfRoomBeforeTheBus() {
        #expect(usableAlertMinutes(arrivalUnix: now + 12 * 60 + 30, now: now) == 11)
        #expect(usableAlertMinutes(arrivalUnix: now + 90, now: now) == 0)
        #expect(usableAlertMinutes(arrivalUnix: now - 60, now: now) == 0)
    }

    @Test func firesTheChosenMinutesBeforeTheArrival() {
        #expect(alertFireUnix(arrivalUnix: now + 600, minutesBefore: 5) == now + 300)
    }

    @Test func followsTheEstimateWhenItMovesEnough() {
        let update = updateAlert(fireUnix: now + 300, minutesBefore: 5, arrival: coming(at: now + 900), now: now)

        #expect(update == .move(to: now + 600))
    }

    @Test func ignoresAWobbleOfAFewSeconds() {
        let update = updateAlert(fireUnix: now + 300, minutesBefore: 5, arrival: coming(at: now + 610), now: now)

        #expect(update == .keep)
    }

    @Test func firesRightAwayWhenTheBusSuddenlyGetsCloser() {
        let update = updateAlert(fireUnix: now + 300, minutesBefore: 5, arrival: coming(at: now + 120), now: now)

        #expect(update == .move(to: now))
    }

    @Test func dropsTheAlertOnceTheBusWentBy() {
        let gone = Arrival(
            tripId: "t", lineId: "2812", patternId: "[BNA17]2812_0_2", headsign: "Caneças",
            estimatedUnix: 0, scheduledUnix: now, observedUnix: nil, wentByUnix: now - 30,
            tripRunning: true, vehicleId: "2602"
        )

        #expect(updateAlert(fireUnix: now + 300, minutesBefore: 5, arrival: gone, now: now) == .drop)
    }

    @Test func forgetsAnAlertThatAlreadyFiredSoItDoesNotRingAgain() {
        #expect(updateAlert(fireUnix: now - 5, minutesBefore: 5, arrival: coming(at: now + 240), now: now) == .drop)
    }

    @Test func keepsAnAlertWhoseRowIsMissingUntilItsTimeHasPassed() {
        #expect(updateAlert(fireUnix: now + 300, minutesBefore: 5, arrival: nil, now: now) == .keep)
        #expect(updateAlert(fireUnix: now - 10, minutesBefore: 5, arrival: nil, now: now) == .drop)
    }
}
