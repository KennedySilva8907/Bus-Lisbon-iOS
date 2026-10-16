import Testing
@testable import BusLisbonCore

private let west = Coordinate(lat: 38.75, lon: -9.150)
private let corner = Coordinate(lat: 38.75, lon: -9.140)
private let north = Coordinate(lat: 38.76, lon: -9.140)
private let eastThenNorth = RouteTrack([west, corner, north])!
private let firstLeg = RouteTrack([west, corner])!.length

private let outAndBack = Route(
    colour: "#C61D23",
    textColour: "#FFFFFF",
    points: [west, corner, Coordinate(lat: 38.7502, lon: -9.140), Coordinate(lat: 38.7502, lon: -9.150)],
    stops: [Coordinate(lat: 38.7501, lon: -9.145), corner, Coordinate(lat: 38.7501, lon: -9.145)]
)

struct TrackTests {
    @Test func placesAPointBesideTheRoadOnTheRoad() throws {
        let along = try #require(eastThenNorth.locate(Coordinate(lat: 38.7502, lon: -9.145)))

        #expect(abs(along - firstLeg / 2) < 5)
    }

    @Test func ignoresAPointFarFromTheRoad() {
        #expect(eastThenNorth.locate(Coordinate(lat: 38.755, lon: -9.145)) == nil)
    }

    @Test func walksAroundTheCorner() {
        let point = eastThenNorth.coordinate(at: firstLeg + 100)

        #expect(abs(metres(corner, point) - 100) < 2)
        #expect(abs(point.lon - corner.lon) < 0.00001)
    }

    @Test func headsTheWayTheRoadGoes() {
        #expect(abs(eastThenNorth.heading(at: 100) - 90) < 1)
        #expect(turn(between: eastThenNorth.heading(at: eastThenNorth.length - 100), and: 0) < 1)
    }

    @Test func keepsGoingForwardOnAStreetUsedBothWays() throws {
        let track = try #require(RouteTrack(outAndBack.points))
        let beside = Coordinate(lat: 38.7501, lon: -9.145)

        let outward = try #require(track.locate(beside, after: 0))
        let inward = try #require(track.locate(beside, after: firstLeg))

        #expect(abs(outward - firstLeg / 2) < 5)
        #expect(inward > firstLeg)
    }

    @Test func usesTheBusHeadingWhenThereIsNoHistory() throws {
        let track = try #require(RouteTrack(outAndBack.points))
        let beside = Coordinate(lat: 38.7501, lon: -9.145)

        let goingEast = try #require(track.locate(beside, heading: 90))
        let goingWest = try #require(track.locate(beside, heading: 270))

        #expect(goingEast < firstLeg)
        #expect(goingWest > firstLeg)
    }

    @Test func placesEachStopAfterThePreviousOne() throws {
        let route = try #require(FollowedRoute(outAndBack))
        let alongs = route.stopAlongs.compactMap { $0 }

        #expect(alongs.count == 3)
        #expect(alongs == alongs.sorted())
        #expect(alongs[2] > firstLeg)
    }

    @Test func marksTheStopsTheBusHasPassed() throws {
        let route = try #require(FollowedRoute(outAndBack))

        #expect(route.passed(0, bus: firstLeg - 10))
        #expect(!route.passed(1, bus: firstLeg - 10))
        #expect(!route.passed(0, bus: nil))
    }

    @Test func spacesArrowsAfterTheBusAndKeepsThemOffStops() {
        let spots = eastThenNorth.arrowSpots(from: 0, to: 800, every: 200, clearing: [410], by: 30)

        #expect(spots == [200, 600])
    }

    @Test func keepsArrowsOffBends() {
        let step = firstLeg / 4
        let spots = eastThenNorth.arrowSpots(from: 0, to: eastThenNorth.length, every: step, clearing: [], by: 40)

        #expect(spots.contains { abs($0 - step * 3) < 0.01 })
        #expect(!spots.contains { abs($0 - firstLeg) < 0.01 })
        #expect(spots.contains { abs($0 - step * 5) < 0.01 })
    }

    @Test func glidesForwardAndHoldsOnSmallBackwardNoise() {
        #expect(nextMove(from: nil, to: 300) == .jump(to: 300))
        #expect(nextMove(from: 100, to: 300) == .glide(from: 100, to: 300))
        #expect(nextMove(from: 300, to: 250) == .hold)
        #expect(nextMove(from: 300, to: 100) == .jump(to: 100))
        #expect(nextMove(from: 100, to: 900) == .jump(to: 900))
    }
}
