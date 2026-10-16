import Testing
@testable import BusLisbonCore

struct MapStyleTests {
    @Test func holdsTheFirstValueBelowTheFirstZoom() {
        #expect(MapStyle.stopRadius.at(5) == 1.5)
    }

    @Test func holdsTheLastValueAboveTheLastZoom() {
        #expect(MapStyle.stopRadius.at(30) == 8)
    }

    @Test func interpolatesBetweenTwoZooms() {
        #expect(abs(MapStyle.stopRadius.at(17) - 6.25) < 0.000001)
    }

    @Test func picksTheRightPairWhenThereAreSeveral() {
        #expect(abs(MapStyle.vehicleSize.at(14) - 0.60) < 0.000001)
        #expect(abs(MapStyle.vehicleGlowRadius.at(16) - 31.5) < 0.000001)
    }

    @Test func hidesTheOtherStopsWhileFollowingFromFarAway() {
        #expect(MapStyle.mutedStopAlpha.at(12) == 0)
        #expect(abs(MapStyle.mutedStopAlpha.at(14.25) - 0.375) < 0.000001)
        #expect(MapStyle.mutedStopAlpha.at(17) == 0.75)
    }

    @Test func turnsAMapKitZoomScaleIntoTheWebAppZoom() {
        #expect(mapZoom(zoomScale: 1) == 19)
        #expect(mapZoom(zoomScale: 0.25) == 17)
    }
}
