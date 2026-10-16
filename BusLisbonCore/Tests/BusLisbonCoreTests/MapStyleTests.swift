import Testing
@testable import BusLisbonCore

struct MapStyleTests {
    @Test func holdsTheFirstValueBelowTheFirstZoom() {
        #expect(MapStyle.stopRadius.at(5) == 1)
    }

    @Test func holdsTheLastValueAboveTheLastZoom() {
        #expect(MapStyle.stopRadius.at(30) == 20)
    }

    @Test func interpolatesBetweenTwoZooms() {
        #expect(abs(MapStyle.stopRadius.at(17.5) - 10.5) < 0.000001)
    }

    @Test func picksTheRightPairWhenThereAreSeveral() {
        #expect(abs(MapStyle.vehicleSize.at(14) - 0.60) < 0.000001)
        #expect(abs(MapStyle.vehicleGlowRadius.at(16) - 31.5) < 0.000001)
    }

    @Test func turnsAMapKitZoomScaleIntoTheWebAppZoom() {
        #expect(mapZoom(zoomScale: 1) == 19)
        #expect(mapZoom(zoomScale: 0.25) == 17)
    }
}
