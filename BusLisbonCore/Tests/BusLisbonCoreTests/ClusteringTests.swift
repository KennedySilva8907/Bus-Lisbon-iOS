import Testing
@testable import BusLisbonCore

private let a = Stop(id: "a", name: "A", lat: 38.71, lon: -9.11)
private let b = Stop(id: "b", name: "B", lat: 38.72, lon: -9.12)
private let c = Stop(id: "c", name: "C", lat: 38.73, lon: -9.13)
private let d = Stop(id: "d", name: "D", lat: 38.80, lon: -9.10)
private let far = Stop(id: "far", name: "Far", lat: 40.0, lon: -9.0)

private let wide = MapBox(minLat: 38.0, maxLat: 39.0, minLon: -10.0, maxLon: -8.0)

struct ClusteringTests {
    @Test func groupsTheStopsOfOneCellIntoOneCircleAtTheirAverage() throws {
        let groups = clusterStops([a, b, c, d], in: wide, cellSize: 0.25, showAllBelow: 3)

        let group = try #require(groups.first { $0.count == 3 })
        #expect(abs(group.lat - 38.72) < 0.000001)
        #expect(abs(group.lon - -9.12) < 0.000001)
        #expect(group.stop == nil)
    }

    @Test func givesTheStopItselfWhenACellHasOnlyOne() {
        let groups = clusterStops([a, b, c, d], in: wide, cellSize: 0.25, showAllBelow: 3)

        #expect(groups.contains { $0.count == 1 && $0.stop == d })
        #expect(groups.count == 2)
    }

    @Test func showsEveryStopWhenFewAreVisible() {
        let groups = clusterStops([a, b, c, d], in: wide, cellSize: 0.25, showAllBelow: 10)

        #expect(groups.map(\.stop?.id) == ["a", "b", "c", "d"])
    }

    @Test func leavesOutWhatIsNotOnScreen() {
        let groups = clusterStops([a, far], in: wide, cellSize: 0.25, showAllBelow: 10)

        #expect(groups.map(\.stop?.id) == ["a"])
    }

    @Test func keepsTheSameCirclesWhenTheMapIsDragged() {
        let dragged = MapBox(minLat: 38.1, maxLat: 39.1, minLon: -9.9, maxLon: -7.9)

        #expect(clusterStops([a, b, c, d], in: wide, cellSize: 0.25, showAllBelow: 3)
            == clusterStops([a, b, c, d], in: dragged, cellSize: 0.25, showAllBelow: 3))
    }

    @Test func picksAPowerOfTwoCellSoZoomingChangesItInSteps() {
        #expect(clusterCellSize(span: 1.5) == 0.25)
        #expect(clusterCellSize(span: 0.08) == 0.0078125)
    }
}
