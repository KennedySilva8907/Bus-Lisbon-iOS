import Testing
@testable import BusLisbonCore

struct FrameAroundTests {
    @Test func wrapsBothPointsWithAMarginSoNeitherSitsOnTheEdge() throws {
        let frame = try #require(frameAround([Coordinate(lat: 38.7, lon: -9.2), Coordinate(lat: 38.75, lon: -9.1)]))

        #expect(abs(frame.southWest.lon - (-9.2 - frameMargin)) < 0.000001)
        #expect(abs(frame.northEast.lat - (38.75 + frameMargin)) < 0.000001)
    }

    @Test func stillGivesAFrameWhenThereIsOnlyOnePoint() throws {
        let frame = try #require(frameAround([Coordinate(lat: 38.7, lon: -9.2)]))

        #expect(frame.northEast.lon > frame.southWest.lon)
        #expect(frame.northEast.lat > frame.southWest.lat)
    }

    @Test func ignoresAPointWithNoUsablePosition() throws {
        let frame = try #require(frameAround([Coordinate(lat: 38.7, lon: -9.2), Coordinate(lat: 38.9, lon: .nan)]))

        #expect(abs(frame.northEast.lat - (38.7 + frameMargin)) < 0.000001)
    }

    @Test func givesNothingWhenThereIsNothingToFrame() {
        #expect(frameAround([]) == nil)
        #expect(frameAround([Coordinate(lat: .nan, lon: .nan)]) == nil)
    }
}

struct FramePaddingTests {
    @Test func liftsTheFrameClearOfWhateverCoversTheBottom() {
        #expect(framePadding(width: 400, height: 800, covered: 440).bottom == 440 + frameGap)
    }

    @Test func stillLeavesRoomForTheSearchBarOnTop() {
        #expect(framePadding(width: 400, height: 800, covered: 440).top == frameTop)
    }

    @Test func usesTheWholeMapWhenNothingCoversIt() {
        #expect(framePadding(width: 400, height: 800, covered: 0) == Insets(top: frameTop, bottom: frameGap, left: 40, right: 40))
    }

    @Test func givesUpTheTopStripBeforeItGivesUpTheVisibleBand() {
        let padding = framePadding(width: 400, height: 800, covered: 700)

        #expect(padding.top == 0)
        #expect(800 - padding.top - padding.bottom >= frameMinView)
    }

    @Test func neverAsksForMorePaddingThanTheMapHasRoomFor() {
        let padding = framePadding(width: 320, height: 400, covered: 5000)

        #expect(padding.top + padding.bottom <= 400 - frameMinView)
        #expect(padding.left + padding.right <= 320 - frameMinView)
    }

    @Test func dropsTheSideMarginsOnANarrowMapRatherThanSqueezingItFlat() {
        #expect(framePadding(width: 180, height: 800, covered: 0).left == 20)
    }
}

struct FittedRectTests {
    private let insets = Insets(top: 96, bottom: 56, left: 40, right: 40)

    @Test func centresALonePointInTheUncoveredPartAtTheGivenZoom() {
        let rect = fittedRect(PlaneRect(x: 1000, y: 1000, width: 0, height: 0), width: 400, height: 800, insets: insets, maxZoom: 16)

        #expect(rect == PlaneRect(x: -600, y: -2360, width: 3200, height: 6400))
    }

    @Test func zoomsOutToFitAWideFrame() {
        let rect = fittedRect(PlaneRect(x: 0, y: 0, width: 3200, height: 1600), width: 400, height: 800, insets: Insets(top: 0, bottom: 0, left: 0, right: 0), maxZoom: 17)

        #expect(rect == PlaneRect(x: 0, y: -2400, width: 3200, height: 6400))
    }

    @Test func neverZoomsInPastTheLimitWhenTheBusIsAtTheStop() {
        let rect = fittedRect(PlaneRect(x: 0, y: 0, width: 10, height: 10), width: 400, height: 800, insets: insets, maxZoom: 17)

        #expect(rect.width == 400 / 0.25)
    }
}
