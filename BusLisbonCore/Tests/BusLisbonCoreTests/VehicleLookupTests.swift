import Foundation
import Testing
@testable import BusLisbonCore

private struct NotStubbed: Error {}

private let backend = "https://ca-buslisbon-api.politeglacier-dcb5b974.spaincentral.azurecontainerapps.io"
private let trip = "[TPNBR][BNA17]2772_0_1|1|1|2520"
private let vehicleJSON = #"{"vehicle":{"id":"[BNA17]2597","lat":38.766495,"lon":-9.157588,"lineId":"2772","patternId":"[TPNBR][BNA17]2772_0_1","tripId":"[TPNBR][BNA17]2772_0_1|1|1|2520","bearing":338,"speed":51,"timestamp":1792110234,"stopId":"060159","currentStatus":"IN_TRANSIT_TO"},"ageSeconds":4.7,"stale":false}"#

private func bus(_ id: String, line: String = "2772") -> BusPosition {
    BusPosition(id: id, lat: 38.76, lon: -9.15, lineId: line, patternId: nil, bearing: nil, timestamp: nil)
}

struct FleetIdTests {
    @Test func acceptsTheIdsTheFleetFeedUses() {
        #expect(isFleetVehicleId("41|300"))
        #expect(isFleetVehicleId("42|2512"))
        #expect(isFleetVehicleId("[BNA17]2547"))
        #expect(isFleetVehicleId("[LA77N]1130"))
    }

    @Test func rejectsTheBareNumbersTheArrivalsServiceSends() {
        #expect(!isFleetVehicleId("2597"))
        #expect(!isFleetVehicleId("544"))
        #expect(!isFleetVehicleId(""))
    }
}

struct VehicleLookupTests {
    @Test func buildsTheTripLookupWithTheNumberAndTheLine() {
        #expect(Endpoint.vehicleOnTrip(trip, number: "2597", lineId: "2772").absoluteString
            == backend + "/api/vehicles/by-trip/%5BTPNBR%5D%5BBNA17%5D2772_0_1%7C1%7C1%7C2520?number=2597&lineId=2772")
    }

    @Test func asksByTripWhenTheIdIsABareNumber() async throws {
        let url = Endpoint.vehicleOnTrip(trip, number: "2597", lineId: "2772").absoluteString
        let api = BusLisbonAPI { asked, _ in
            guard asked.absoluteString == url else { throw NotStubbed() }
            return (Data(vehicleJSON.utf8), 200)
        }

        let found = try await api.vehicle(id: "2597", tripId: trip, lineId: "2772")

        #expect(found?.id == "[BNA17]2597")
    }

    @Test func asksByIdWhenTheIdIsAFleetOne() async throws {
        let url = Endpoint.vehicle("[BNA17]2597").absoluteString
        let api = BusLisbonAPI { asked, _ in
            guard asked.absoluteString == url else { throw NotStubbed() }
            return (Data(vehicleJSON.utf8), 200)
        }

        let found = try await api.vehicle(id: "[BNA17]2597", tripId: trip, lineId: "2772")

        #expect(found?.id == "[BNA17]2597")
    }

    @Test func findsTheBusInTheFeedByItsFullId() {
        #expect(findBus(in: [bus("[BNA17]2597")], id: "[BNA17]2597", lineId: "2772")?.id == "[BNA17]2597")
    }

    @Test func findsTheBusInTheFeedByItsBareNumberOnTheSameLine() {
        #expect(findBus(in: [bus("[BNA17]1597"), bus("[BNA17]2597")], id: "2597", lineId: "2772")?.id == "[BNA17]2597")
    }

    @Test func doesNotTakeABusWithTheSameNumberOnAnotherLine() {
        #expect(findBus(in: [bus("[XS3H8]2597", line: "1223")], id: "2597", lineId: "2772") == nil)
    }
}
