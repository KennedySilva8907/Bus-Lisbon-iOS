import Foundation
import Testing
@testable import BusLisbonCore

private func line(
    _ lineId: String = "1005",
    passages: Int = 100,
    withinTolerance: Int = 100
) -> RankedLine {
    RankedLine(
        lineId: lineId,
        passages: passages,
        withinTolerance: withinTolerance,
        late: 0,
        early: 0,
        averageLatenessSeconds: 0,
        firstServiceDate: "2026-08-18",
        lastServiceDate: "2026-08-19"
    )
}

private let noon = 1_787_140_800
private let ranked = [line("1005"), line("1702"), line("2222")]

struct ReliabilityTests {
    @Test func readsTheRankingTheBackendPublishes() throws {
        let json = #"{"computedAtUnix":1792213275,"toleranceSeconds":300,"lines":[{"lineId":"1702","passages":412,"withinTolerance":301,"late":40,"early":71,"averageLatenessSeconds":-95.5,"firstServiceDate":"2026-09-18","lastServiceDate":"2026-10-17"}]}"#

        let ranking = try JSONDecoder().decode(LineRanking.self, from: Data(json.utf8))

        #expect(ranking.toleranceSeconds == 300)
        #expect(ranking.lines.first?.lineId == "1702")
        #expect(ranking.lines.first?.averageLatenessSeconds == -95.5)
    }

    @Test func roundsToAWholePercent() {
        #expect(punctualityPercent(line(passages: 90, withinTolerance: 6)) == 7)
    }

    @Test func doesNotDivideByZeroWhenALineHasNoPassages() {
        #expect(punctualityPercent(line(passages: 0, withinTolerance: 0)) == 0)
    }

    @Test func saysEarlyWhenTheBusRunsAheadOfTheTimetable() {
        #expect(describeAverage(-716) == "12 min adiantada")
    }

    @Test func saysLateWhenItRunsBehind() {
        #expect(describeAverage(280) == "5 min atrasada")
    }

    @Test func doesNotCallHalfAMinuteADelay() {
        #expect(describeAverage(-20) == "à tabela")
    }

    @Test func turnsTheToleranceIntoMinutes() {
        #expect(describeToleranceLabel(300) == "dentro de 5 min do horário")
    }

    @Test func saysNothingHasBeenComputedYet() {
        #expect(describeFreshness(computedAtUnix: 0, now: noon) == "Ainda sem dados")
    }

    @Test func readsASummaryFromThisMorningAsToday() {
        #expect(describeFreshness(computedAtUnix: noon - 37_800, now: noon) == "Actualizado hoje")
    }

    @Test func countsTheDaysWhenTheJobHasNotRun() {
        #expect(describeFreshness(computedAtUnix: noon - 297_000, now: noon) == "Actualizado há 3 dias")
    }

    @Test func pullsTheChosenLinesOutAndKeepsTheRestInOrder() {
        let split = splitByFavourites(ranked, favourites: ["2222", "1005"])

        #expect(split.mine.map(\.lineId) == ["1005", "2222"])
        #expect(split.rest.map(\.lineId) == ["1702"])
    }

    @Test func reportsAChosenLineThatHasNoNumberYetInsteadOfDroppingIt() {
        let split = splitByFavourites(ranked, favourites: ["1005", "9999"])

        #expect(split.missing == ["9999"])
        #expect(split.mine.map(\.lineId) == ["1005"])
    }

    @Test func leavesEverythingInTheRestWhenNothingIsChosen() {
        let split = splitByFavourites(ranked, favourites: [])

        #expect(split.mine.isEmpty)
        #expect(split.missing.isEmpty)
        #expect(split.rest.count == 3)
    }

    @Test func callsALineVeryReliableFrom90Up() {
        #expect(describeTrust(90).label == "Muito fiável")
        #expect(describeTrust(100).level == .high)
    }

    @Test func doesNotPromote89ToTheTopBand() {
        #expect(describeTrust(89).label == "Fiável")
    }

    @Test func callsTheMiddleBandUneven() {
        #expect(describeTrust(50).label == "Irregular")
        #expect(describeTrust(69).level == .uneven)
    }

    @Test func isBluntBelowHalf() {
        #expect(describeTrust(49).label == "Pouco fiável")
        #expect(describeTrust(7).level == .low)
    }

    @Test func readsARangeInsideOneMonth() {
        #expect(describeServiceWindow("2026-08-18", "2026-08-19") == "18 a 19 de agosto")
    }

    @Test func namesASingleDayOnce() {
        #expect(describeServiceWindow("2026-08-19", "2026-08-19") == "19 de agosto")
    }

    @Test func spellsBothMonthsWhenTheWindowCrossesOne() {
        #expect(describeServiceWindow("2026-07-28", "2026-08-19") == "28 de julho a 19 de agosto")
    }
}
