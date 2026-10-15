import Foundation
import Testing
@testable import BusLisbonCore

private let now = 1_787_340_000

private func entry(
    lineId: String = "2753",
    vehicleId: String = "1257",
    scheduledUnix: Int = now + 240,
    estimatedUnix: Int = now + 300,
    isPast: Bool = false,
    isRealtime: Bool = true,
    tripRunning: Bool = true,
    fromTheBus: Bool? = nil
) -> BoardEntry {
    BoardEntry(
        lineId: lineId,
        patternId: "[BNA17]2753_0_1",
        headsign: "Milharado",
        tripId: "[0277F][BNA17]2753_0_1|1|3|1835",
        vehicleId: vehicleId,
        scheduledUnix: scheduledUnix,
        estimatedUnix: estimatedUnix,
        isPast: isPast,
        isRealtime: isRealtime,
        tripRunning: tripRunning,
        fromTheBus: fromTheBus
    )
}

private func arrival(
    lineId: String = "1235",
    estimatedUnix: Int = 1_755_380_000,
    scheduledUnix: Int = 1_755_380_000,
    observedUnix: Int? = nil,
    wentByUnix: Int? = nil,
    tripRunning: Bool = false,
    vehicleId: String = ""
) -> Arrival {
    Arrival(
        tripId: "t-\(lineId)-\(scheduledUnix)",
        lineId: lineId,
        patternId: "1235_0_2",
        headsign: "Cascais",
        estimatedUnix: estimatedUnix,
        scheduledUnix: scheduledUnix,
        observedUnix: observedUnix,
        wentByUnix: wentByUnix,
        tripRunning: tripRunning,
        vehicleId: vehicleId
    )
}

struct BoardDecodingTests {
    @Test func readsTheBoardTheBackendSends() throws {
        let json = #"[{"lineId":"1223","patternId":"1223_0_1","headsign":"Portela Sintra (Estação Sul)","tripId":"[LA77N]1223_0_1_1000_1029_0_4","vehicleId":"","scheduledUnix":1789118460,"estimatedUnix":0,"isPast":true,"isRealtime":false,"tripRunning":false,"fromTheBus":false}]"#

        let board = try JSONDecoder().decode([BoardEntry].self, from: Data(json.utf8))

        #expect(board == [
            BoardEntry(
                lineId: "1223", patternId: "1223_0_1", headsign: "Portela Sintra (Estação Sul)",
                tripId: "[LA77N]1223_0_1_1000_1029_0_4", vehicleId: "", scheduledUnix: 1_789_118_460,
                estimatedUnix: 0, isPast: true, isRealtime: false, tripRunning: false, fromTheBus: false
            ),
        ])
    }

    @Test func readsARowWithoutFromTheBus() throws {
        let json = #"[{"lineId":"1","patternId":"p","headsign":"h","tripId":"t","vehicleId":"","scheduledUnix":1,"estimatedUnix":0,"isPast":false,"isRealtime":false,"tripRunning":false}]"#

        let board = try JSONDecoder().decode([BoardEntry].self, from: Data(json.utf8))

        #expect(board.first?.fromTheBus == nil)
    }
}

struct ToArrivalsTests {
    @Test func givesARunningBusItsEstimateAndLetsItBeFollowed() {
        let result = toArrivals([entry()])[0]

        #expect(result.estimatedUnix == now + 300)
        #expect(result.scheduledUnix == now + 240)
        #expect(result.vehicleId == "1257")
        #expect(result.observedUnix == nil)
    }

    @Test func turnsAPastEntryIntoAPassageStillWorthFollowing() {
        let result = toArrivals([entry(estimatedUnix: now - 600, isPast: true)])[0]

        #expect(result.observedUnix == now - 600)
        #expect(result.estimatedUnix == 0)
        #expect(result.vehicleId == "1257")
    }

    @Test func doesNotOfferToFollowADepartureWithNoBusYet() {
        let result = toArrivals([entry(estimatedUnix: 0, isRealtime: false, tripRunning: false)])[0]

        #expect(result.vehicleId == "")
        #expect(result.estimatedUnix == 0)
        #expect(result.scheduledUnix == now + 240)
    }

    @Test func carriesTheTripAcross() {
        #expect(toArrivals([entry()])[0].tripId == "[0277F][BNA17]2753_0_1|1|3|1835")
    }

    @Test func keepsTheOrderTheAPISent() {
        let board = [entry(lineId: "1"), entry(lineId: "2"), entry(lineId: "3")]

        #expect(toArrivals(board).map(\.lineId) == ["1", "2", "3"])
    }

    @Test func givesNoObservedTimeToAPassageThatHadNoEstimate() {
        let result = toArrivals([entry(scheduledUnix: now - 900, estimatedUnix: 0, isPast: true, isRealtime: false)])[0]

        #expect(result.observedUnix == nil)
        #expect(result.wentByUnix == now - 900)
    }

    @Test func givesAnObservedTimeOnlyWhenTheBusWasSeen() {
        let result = toArrivals([entry(scheduledUnix: now - 900, estimatedUnix: now - 600, isPast: true, isRealtime: true)])[0]

        #expect(result.observedUnix == now - 600)
        #expect(result.wentByUnix == now - 600)
    }

    @Test func letsABusThatWentByBeFollowed() {
        let result = toArrivals([entry(vehicleId: "2548", estimatedUnix: now - 120, isPast: true)])[0]

        #expect(result.vehicleId == "2548")
    }

    @Test func cannotFollowAPassageOnceTheTripIsOffTheRoad() {
        let result = toArrivals([entry(estimatedUnix: 0, isPast: true, isRealtime: false, tripRunning: false)])[0]

        #expect(result.vehicleId == "")
        #expect(result.tripRunning == false)
    }

    @Test func canFollowAPassageWhileTheTripIsBeingDriven() {
        let result = toArrivals([entry(vehicleId: "42|2524", estimatedUnix: 0, isPast: true, isRealtime: false, tripRunning: true)])[0]

        #expect(result.vehicleId == "42|2524")
        #expect(result.tripRunning == true)
    }

    @Test func doesNotCallATimeWeWorkedOutOurselvesAnObservedArrival() {
        let result = toArrivals([entry(estimatedUnix: now - 600, isPast: true, fromTheBus: true)])[0]

        #expect(result.observedUnix == nil)
        #expect(result.wentByUnix == now - 600)
    }

    @Test func stillCountsOneTheOperatorPublishedAsObserved() {
        let result = toArrivals([entry(estimatedUnix: now - 600, isPast: true, fromTheBus: false)])[0]

        #expect(result.observedUnix == now - 600)
    }
}

struct DescribeArrivalTests {
    @Test func letsYouFollowAnArrivalThatNamesItsBusAndSaysWhen() {
        let description = describeArrival(arrival(estimatedUnix: 1_755_380_180, vehicleId: "41|814"))

        #expect(description == ArrivalDescription(state: .boarding, trackable: true, label: "Em viagem"))
    }

    @Test func willNotSayABusIsComingJustBecauseItIsOutOnTheRoad() {
        let description = describeArrival(arrival(estimatedUnix: 0, vehicleId: "41|814"))

        #expect(description == ArrivalDescription(state: .onTheWay, trackable: true, label: "Agendado · autocarro a caminho"))
    }

    @Test func refusesToFollowAScheduledArrival() {
        let description = describeArrival(arrival())

        #expect(description == ArrivalDescription(state: .scheduled, trackable: false, label: "Agendado · ainda sem autocarro"))
    }

    @Test func refusesToFollowAnEstimateThatNamesNoBus() {
        let description = describeArrival(arrival(estimatedUnix: 1_755_380_600, scheduledUnix: 1_755_380_000))

        #expect(description == ArrivalDescription(state: .predicted, trackable: false, label: "Previsto · ainda sem autocarro"))
    }
}

struct PunctualityTests {
    private let scheduled = 1_787_340_000

    @Test func saysNothingAboutAPassageNobodySaw() {
        #expect(describePunctuality(arrival(scheduledUnix: scheduled, observedUnix: nil)) == nil)
    }

    @Test func callsABusThatWentByEarlyAdiantado() {
        #expect(describePunctuality(arrival(scheduledUnix: scheduled, observedUnix: scheduled - 180))
            == Punctuality(label: "Adiantado", tone: .early))
    }

    @Test func givesTheMinutesForABusThatWentByLate() {
        #expect(describePunctuality(arrival(scheduledUnix: scheduled, observedUnix: scheduled + 300))
            == Punctuality(label: "+5min", tone: .late))
    }

    @Test func callsTheRestPontual() {
        #expect(describePunctuality(arrival(scheduledUnix: scheduled, observedUnix: scheduled))
            == Punctuality(label: "Pontual", tone: .onTime))
        #expect(describePunctuality(arrival(scheduledUnix: scheduled, observedUnix: scheduled + 90))
            == Punctuality(label: "Pontual", tone: .onTime))
    }

    @Test func judgesAnUpcomingBusByItsEstimate() {
        #expect(estimatePunctuality(arrival(estimatedUnix: scheduled - 120, scheduledUnix: scheduled))
            == Punctuality(label: "Adiantado", tone: .early))
        #expect(estimatePunctuality(arrival(estimatedUnix: scheduled + 780, scheduledUnix: scheduled))
            == Punctuality(label: "+13min", tone: .late))
        #expect(estimatePunctuality(arrival(estimatedUnix: scheduled + 60, scheduledUnix: scheduled))
            == Punctuality(label: "Pontual", tone: .onTime))
    }

    @Test func saysNothingAboutAnUpcomingBusWithoutAnEstimate() {
        #expect(estimatePunctuality(arrival(estimatedUnix: 0, scheduledUnix: scheduled)) == nil)
    }

    @Test func saysTheBusIsStillOutThere() {
        #expect(describePassage(arrival(tripRunning: true)) == Punctuality(label: "Ainda em percurso", tone: .running))
    }

    @Test func saysTheTripIsOver() {
        #expect(describePassage(arrival(tripRunning: false)) == Punctuality(label: "Terminou o percurso", tone: .finished))
    }
}

struct WentByAndRealtimeTests {
    @Test func usesTheTimeTheBoardSaysItWentBy() {
        #expect(wentByAt(arrival(observedUnix: 1_787_340_222, wentByUnix: 1_787_340_111)) == 1_787_340_111)
    }

    @Test func fallsBackToTheObservedTime() {
        #expect(wentByAt(arrival(observedUnix: 1_787_340_222)) == 1_787_340_222)
    }

    @Test func saysNothingForAnArrivalThatHasNotHappened() {
        #expect(wentByAt(arrival()) == nil)
    }

    @Test func seesALiveEstimate() {
        #expect(anyArrivalTime([arrival(estimatedUnix: 0), arrival(estimatedUnix: 1_787_950_000)]))
    }

    @Test func seesAWatchedPassage() {
        #expect(anyArrivalTime([arrival(estimatedUnix: 0, observedUnix: 1_787_949_000)]))
    }

    @Test func isNotFooledByKnowingWhichBusDrivesTheTrip() {
        #expect(!anyArrivalTime([arrival(estimatedUnix: 0, tripRunning: true, vehicleId: "42|2548")]))
    }

    @Test func isFalseForAnEmptyStop() {
        #expect(!anyArrivalTime([]))
    }
}

struct SplitPanelTests {
    @Test func putsWhatWentByInThePastNewestFirst() {
        let older = arrival(lineId: "1", estimatedUnix: 0, scheduledUnix: now - 900, wentByUnix: now - 900)
        let newer = arrival(lineId: "2", estimatedUnix: 0, scheduledUnix: now - 300, wentByUnix: now - 300)

        let split = splitPanel([older, newer], now: now)

        #expect(split.past.map(\.lineId) == ["2", "1"])
        #expect(split.upcoming.isEmpty)
    }

    @Test func sortsWhatIsComingBySoonestFirst() {
        let later = arrival(lineId: "1", estimatedUnix: now + 900, scheduledUnix: now + 900)
        let sooner = arrival(lineId: "2", estimatedUnix: 0, scheduledUnix: now + 120)

        #expect(splitPanel([later, sooner], now: now).upcoming.map(\.lineId) == ["2", "1"])
    }

    @Test func keepsARunningTripWhoseTimeRanOut() {
        let late = arrival(estimatedUnix: now - 120, scheduledUnix: now - 900, tripRunning: true, vehicleId: "[BNA17]2753")

        #expect(splitPanel([late], now: now).upcoming.count == 1)
    }

    @Test func dropsAnExpiredTimeWithNoTripBehindIt() {
        let gone = arrival(estimatedUnix: 0, scheduledUnix: now - 120, tripRunning: false)

        #expect(splitPanel([gone], now: now).upcoming.isEmpty)
    }

    @Test func leavesOutAnythingTwoHoursAwayOrMore() {
        let far = arrival(estimatedUnix: 0, scheduledUnix: now + 7200)

        #expect(splitPanel([far], now: now).upcoming.isEmpty)
    }

    @Test func showsAtMostTwentyUpcoming() {
        let many = (0..<25).map { arrival(lineId: "\($0)", estimatedUnix: 0, scheduledUnix: now + 60 * ($0 + 1)) }

        #expect(splitPanel(many, now: now).upcoming.count == 20)
    }
}

struct LabelTests {
    private let at = 1_789_125_480

    @Test func countsTheMinutesDown() {
        #expect(countdownLabel(at + 300, now: at) == "5min")
        #expect(countdownLabel(at + 60, now: at) == "1min")
    }

    @Test func saysNowWhileTheBusIsArriving() {
        #expect(countdownLabel(at + 10, now: at) == "Agora")
        #expect(countdownLabel(at, now: at) == "Agora")
    }

    @Test func keepsSayingNowWhenTheTimeRanOut() {
        #expect(countdownLabel(at - 120, now: at) == "Agora")
        #expect(countdownLabel(at - 600, now: at) == "Agora")
    }

    @Test func splitsTheHoursOut() {
        #expect(countdownLabel(at + 3600, now: at) == "1h")
        #expect(countdownLabel(at + 3600 + 900, now: at) == "1h15")
    }

    @Test func saysUnderAMinuteInTheSameClockMinute() {
        #expect(countdownLabel(at + 45, now: at) == "<1min")
    }

    @Test func roundsHowLongAgoABusWentBy() {
        #expect(agoLabel(at - 600, now: at) == "Há 10min")
        #expect(agoLabel(at - 89, now: at) == "Há 1min")
    }

    @Test func countsClockMinutesForTheColour() {
        #expect(minutesAway(at + 300, now: at) == 5)
        #expect(minutesAway(at - 120, now: at) == -2)
    }
}
