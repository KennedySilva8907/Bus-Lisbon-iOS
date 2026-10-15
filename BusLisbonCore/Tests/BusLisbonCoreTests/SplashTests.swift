import Testing
@testable import BusLisbonCore

struct SplashTests {
    @Test func startsAtZero() {
        #expect(splashProgress(elapsed: 0) == 0)
    }

    @Test func climbsLikeTheWebApp() {
        #expect(splashProgress(elapsed: 1.6) == 58)
    }

    @Test func neverPassesNinetyTwoOnItsOwn() {
        #expect(splashProgress(elapsed: 100) == 92)
    }

    @Test func waitsFiveSecondsEvenWhenTheStopsAreReady() {
        #expect(!splashCanLeave(elapsed: 4.9, stopsReady: true))
        #expect(splashCanLeave(elapsed: 5, stopsReady: true))
    }

    @Test func leavesAtFifteenEvenWithoutStops() {
        #expect(!splashCanLeave(elapsed: 14.9, stopsReady: false))
        #expect(splashCanLeave(elapsed: 15, stopsReady: false))
    }
}
