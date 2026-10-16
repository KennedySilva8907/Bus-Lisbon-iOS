import Foundation
import Testing
@testable import BusLisbonCore

private struct NotStubbed: Error {}

private let patternJSON = ##"{"color":"#C61D23","text_color":"#000000","shape_id":"137_A6RA0","id":"2812_0_2","path":[{"stop":{"id":"060302","name":"Campo Grande (Metro) P5","lat":"38.759503","lon":"-9.160182"},"stop_sequence":1},{"stop":{"id":"x","name":"Sem sítio","lat":"","lon":""},"stop_sequence":2}]}"##
private let shapeJSON = #"{"geojson":{"geometry":{"coordinates":[[-9.160337,38.75942],[-9.15,38.76],[-9.1]]}}}"#

private let api = BusLisbonAPI { url, _ in
    switch url.absoluteString {
    case "https://api.carrismetropolitana.pt/patterns/2812_0_2": return (Data(patternJSON.utf8), 200)
    case "https://api.carrismetropolitana.pt/shapes/137_A6RA0": return (Data(shapeJSON.utf8), 200)
    default: throw NotStubbed()
    }
}

struct RouteTests {
    @Test func readsLongitudeThenLatitude() async throws {
        let route = try await api.route(patternId: "2812_0_2")

        #expect(route == Route(
            colour: "#C61D23",
            textColour: "#000000",
            points: [
                Coordinate(lat: 38.75942, lon: -9.160337),
                Coordinate(lat: 38.76, lon: -9.15),
            ],
            stops: [Coordinate(lat: 38.759503, lon: -9.160182)]
        ))
    }

    @Test func fallsBackToWhiteTextAndNoStopsWhenThePatternLeavesThemOut() throws {
        let pattern = try JSONDecoder().decode(PatternResponse.self, from: Data(#"{"shape_id":"s"}"#.utf8))

        #expect(pattern.textColour == nil)
        #expect(pattern.stops.isEmpty)
    }

    @Test func keepsARouteOnceFetched() async throws {
        let cache = DiskCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        _ = await loadRoute(patternId: "2812_0_2", cache: cache, api: api)

        let offline = BusLisbonAPI { _, _ in throw NotStubbed() }
        let again = await loadRoute(patternId: "2812_0_2", cache: cache, api: offline)

        #expect(again?.colour == "#C61D23")
    }

    @Test func readsAHexColour() {
        #expect(rgb(hex: "#C61D23") == RGB(red: 198.0 / 255, green: 29.0 / 255, blue: 35.0 / 255))
        #expect(rgb(hex: "C61D23") == RGB(red: 198.0 / 255, green: 29.0 / 255, blue: 35.0 / 255))
        #expect(rgb(hex: "nope") == nil)
    }
}

struct DistanceTests {
    @Test func measuresAThousandthOfADegreeNorth() {
        let distance = metres(Coordinate(lat: 38.7, lon: -9.1), Coordinate(lat: 38.701, lon: -9.1))

        #expect(abs(distance - 111.19) < 0.5)
    }

    @Test func measuresNothingBetweenAPointAndItself() {
        #expect(metres(Coordinate(lat: 38.7, lon: -9.1), Coordinate(lat: 38.7, lon: -9.1)) == 0)
    }

    @Test func slidesAShortHop() {
        #expect(shouldSlide(from: Coordinate(lat: 38.7, lon: -9.1), to: Coordinate(lat: 38.701, lon: -9.1)))
    }

    @Test func jumpsAcrossTown() {
        #expect(!shouldSlide(from: Coordinate(lat: 38.7139, lon: -9.1394), to: Coordinate(lat: 38.7253, lon: -9.15)))
    }
}
