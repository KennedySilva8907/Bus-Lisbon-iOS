import Testing
@testable import BusLisbonCore

private let stops = [
    Stop(id: "060161", name: "Estr. Desvio", lat: 38.77, lon: -9.15, locality: "Lisboa"),
    Stop(id: "060162", name: "Rua Angola", lat: 38.79, lon: -9.12, locality: "Olival Basto"),
    Stop(id: "110061", name: "Caneças (Escola Secundária)", lat: 38.81, lon: -9.22, locality: "Odivelas"),
    Stop(id: "120001", name: "Av. São Sebastião", lat: 38.73, lon: -9.15, locality: "Lisboa"),
]

struct SearchTests {
    @Test func findsByName() {
        #expect(searchStops("angola", in: stops).map(\.id) == ["060162"])
    }

    @Test func ignoresCaseAndAccents() {
        #expect(searchStops("SAO SEBASTIAO", in: stops).map(\.id) == ["120001"])
        #expect(searchStops("canecas", in: stops).map(\.id) == ["110061"])
    }

    @Test func needsEveryWordButNotInOrder() {
        #expect(searchStops("secundaria caneças", in: stops).map(\.id) == ["110061"])
        #expect(searchStops("rua desvio", in: stops).isEmpty)
    }

    @Test func findsByLocality() {
        #expect(searchStops("olival", in: stops).map(\.id) == ["060162"])
    }

    @Test func putsStopNumbersFirst() {
        #expect(searchStops("0601", in: stops).map(\.id) == ["060161", "060162"])
    }

    @Test func givesNothingForAnEmptyQuery() {
        #expect(searchStops("   ", in: stops).isEmpty)
    }

    @Test func stopsAtTheLimit() {
        #expect(searchStops("lisboa", in: stops, limit: 1).count == 1)
    }

    @Test func answersTheSameFromAPrebuiltIndex() {
        let index = StopSearchIndex(stops)

        #expect(index.search("sao sebastiao").map(\.id) == ["120001"])
        #expect(index.search("0601").map(\.id) == ["060161", "060162"])
    }

    @Test func givesEightResultsLikeTheWebApp() {
        let many = (0..<20).map { Stop(id: "9\($0)", name: "Rua \($0)", lat: 38.7, lon: -9.1) }

        #expect(StopSearchIndex(many).search("rua").count == 8)
    }

    @Test func foldsPortugueseLetters() {
        #expect(fold("ÁÀÂÃÉÊÍÓÔÕÚÇ") == "aaaaeeiooouc")
    }
}
