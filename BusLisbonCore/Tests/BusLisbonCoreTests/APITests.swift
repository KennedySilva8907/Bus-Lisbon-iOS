import Foundation
import Testing
@testable import BusLisbonCore

private struct NotStubbed: Error {}

private let backend = "https://ca-buslisbon-api.politeglacier-dcb5b974.spaincentral.azurecontainerapps.io"

private func api(_ answers: [String: (body: String, status: Int)]) -> BusLisbonAPI {
    BusLisbonAPI { url, _ in
        guard let answer = answers[url.absoluteString] else { throw NotStubbed() }
        return (Data(answer.body.utf8), answer.status)
    }
}

struct EndpointTests {
    @Test func percentEncodesABracketedVehicleId() {
        #expect(Endpoint.vehicle("[BNA17]2547").absoluteString == backend + "/api/vehicles/%5BBNA17%5D2547")
    }

    @Test func percentEncodesAPipe() {
        #expect(Endpoint.vehicle("41|300").absoluteString == backend + "/api/vehicles/41%7C300")
    }

    @Test func keepsASlashAQuestionMarkAndAHashInsideTheId() {
        #expect(Endpoint.vehicle("a/b?c#d").absoluteString == backend + "/api/vehicles/a%2Fb%3Fc%23d")
    }

    @Test func leavesAPlainStopIdAlone() {
        #expect(Endpoint.board("060161").absoluteString == backend + "/api/arrivals/by-stop/060161")
    }

    @Test func leavesThePatternIdAlone() {
        #expect(Endpoint.pattern("2812_0_2").absoluteString == "https://api.carrismetropolitana.pt/patterns/2812_0_2")
    }
}

struct APITests {
    private let vehicleJSON = #"{"vehicle":{"id":"[BNA17]2547","lat":38.81382,"lon":-9.223133,"lineId":"2812","patternId":"[JU98X][BNA17]2812_0_2","tripId":"[JU98X][BNA17]2812_0_2|1|2|1230","bearing":256,"speed":9,"timestamp":1789128315,"stopId":"110059","currentStatus":"IN_TRANSIT_TO"},"ageSeconds":6.6309895,"stale":false}"#

    @Test func readsTheVehicleTheBackendSends() async throws {
        let bus = try await api([backend + "/api/vehicles/%5BBNA17%5D2547": (vehicleJSON, 200)])
            .vehicle(id: "[BNA17]2547")

        #expect(bus == BusPosition(
            id: "[BNA17]2547", lat: 38.81382, lon: -9.223133, lineId: "2812",
            patternId: "[JU98X][BNA17]2812_0_2", bearing: 256, timestamp: 1_789_128_315
        ))
    }

    @Test func saysNothingWhenTheBackendDoesNotKnowTheBus() async throws {
        let bus = try await api([backend + "/api/vehicles/gone": ("", 404)]).vehicle(id: "gone")

        #expect(bus == nil)
    }

    @Test func throwsWhenTheBackendFails() async {
        await #expect(throws: APIError.status(503)) {
            try await api([backend + "/api/vehicles/x": ("", 503)]).vehicle(id: "x")
        }
    }

    @Test func readsTheFleetInMillisecondsAndSkipsARowWithoutAPosition() async throws {
        let fleetJSON = #"[{"id":"[A2L1N]12080","lat":38.52108,"lon":-8.881515,"line_id":"4481","pattern_id":"[F1M13][A2L1N]4481_0_3","timestamp":1789125473000,"bearing":115,"current_status":"INCOMING_AT"},{"id":"|undefined","agency_id":""}]"#

        let fleet = try await api(["https://api.carrismetropolitana.pt/v2/vehicles": (fleetJSON, 200)]).fleet()

        #expect(fleet == [BusPosition(
            id: "[A2L1N]12080", lat: 38.52108, lon: -8.881515, lineId: "4481",
            patternId: "[F1M13][A2L1N]4481_0_3", bearing: 115, timestamp: 1_789_125_473_000
        )])
    }

    @Test func readsTheBoard() async throws {
        let boardJSON = #"[{"lineId":"2772","patternId":"2772_0_1","headsign":"Torres da Bela Vista","tripId":"[BNA17]2772_0_1|7|2|1240","vehicleId":"[BNA17]2513","scheduledUnix":1789128000,"estimatedUnix":1789128120,"isPast":false,"isRealtime":true,"tripRunning":true,"fromTheBus":true}]"#

        let board = try await api([backend + "/api/arrivals/by-stop/060161": (boardJSON, 200)]).board(stopId: "060161")

        #expect(toArrivals(board).first?.vehicleId == "[BNA17]2513")
    }

    @Test func readsTheStopsAndSkipsABrokenOne() async throws {
        let stopsJSON = #"[{"id":"1","name":"A","lat":"","lon":"-9.1"},{"id":"2","name":"B","lat":"38.7","lon":"-9.1"}]"#

        let stops = try await api(["https://api.carrismetropolitana.pt/stops": (stopsJSON, 200)]).stops()

        #expect(stops.map(\.id) == ["2"])
    }

    @Test func wakesTheBackendWithoutCaringWhetherItAnswers() async {
        await BusLisbonAPI { _, _ in throw NotStubbed() }.wake()
    }
}
