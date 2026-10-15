import Foundation
import Testing
@testable import BusLisbonCore

struct StopTests {
    private func decode(_ json: String) throws -> [Stop] {
        try JSONDecoder().decode(LossyArray<Stop>.self, from: Data(json.utf8)).elements
    }

    @Test func readsALatitudeSentAsText() throws {
        let stops = try decode(#"[{"id":"010001","name":"Rua Carlos Manuel Rodrigues Francisco (Escola)","lat":"38.754244","lon":"-8.959557","locality":"Alcochete","lines":["4001","4002"],"operational_status":"ACTIVE"}]"#)

        #expect(stops == [
            Stop(id: "010001", name: "Rua Carlos Manuel Rodrigues Francisco (Escola)", lat: 38.754244, lon: -8.959557, locality: "Alcochete", lines: ["4001", "4002"]),
        ])
    }

    @Test func readsALatitudeSentAsANumber() throws {
        let stops = try decode(#"[{"id":"010001","name":"Escola","lat":38.754244,"lon":-8.959557}]"#)

        #expect(stops.first?.lat == 38.754244)
        #expect(stops.first?.lines == [])
    }

    @Test func skipsAStopItCannotPlaceAndKeepsTheRest() throws {
        let stops = try decode(#"[{"id":"1","name":"A","lat":"","lon":"-9.1"},{"id":"2","name":"B","lat":null,"lon":"-9.1"},{"id":"3","name":"C","lat":"0","lon":"0"},"junk",{"id":"4","name":"D","lat":"38.7","lon":"-9.1"}]"#)

        #expect(stops.map(\.id) == ["4"])
    }

    @Test func readsAnIdSentAsANumber() throws {
        let stops = try decode(#"[{"id":10001,"name":"Escola","lat":"38.7","lon":"-9.1"}]"#)

        #expect(stops.first?.id == "10001")
    }

    @Test func survivesTheRoundTripThroughTheCache() throws {
        let stop = Stop(id: "060161", name: "Estr. Desvio", lat: 38.7765, lon: -9.1578, locality: "Lisboa", lines: ["2764"])

        let again = try JSONDecoder().decode(Stop.self, from: JSONEncoder().encode(stop))

        #expect(again == stop)
    }
}
