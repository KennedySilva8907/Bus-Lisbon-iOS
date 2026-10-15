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
