import Testing
@testable import BusLisbonCore

private let stops = [
    Stop(id: "060161", name: "Estr. Desvio", lat: 38.77, lon: -9.15, locality: "Lisboa"),
    Stop(id: "060162", name: "Rua Angola", lat: 38.79, lon: -9.12, locality: "Olival Basto"),
    Stop(id: "110061", name: "Caneças (Escola Secundária)", lat: 38.81, lon: -9.22, locality: "Odivelas"),
    Stop(id: "120001", name: "Av. São Sebastião", lat: 38.73, lon: -9.15, locality: "Lisboa"),
]

private let index = StopSearchIndex(stops)

struct SearchTests {
    @Test func findsByName() {
        #expect(index.search("angola").map(\.id) == ["060162"])
    }

    @Test func ignoresCaseAndAccents() {
        #expect(index.search("SAO SEBASTIAO").map(\.id) == ["120001"])
        #expect(index.search("canecas").map(\.id) == ["110061"])
    }

    @Test func needsEveryWordButNotInOrder() {
        #expect(index.search("secundaria caneças").map(\.id) == ["110061"])
        #expect(index.search("rua desvio").isEmpty)
    }

    @Test func findsByLocality() {
        #expect(index.search("olival").map(\.id) == ["060162"])
    }

    @Test func putsStopNumbersFirst() {
        #expect(index.search("0601").map(\.id) == ["060161", "060162"])
    }

    @Test func givesNothingForAnEmptyQuery() {
        #expect(index.search("   ").isEmpty)
    }

    @Test func stopsAtTheLimit() {
        #expect(index.search("lisboa", limit: 1).count == 1)
    }

    @Test func givesEightResultsLikeTheWebApp() {
        let many = (0..<20).map { Stop(id: "9\($0)", name: "Rua \($0)", lat: 38.7, lon: -9.1) }

        #expect(StopSearchIndex(many).search("rua").count == 8)
    }

    @Test func foldsPortugueseLetters() {
        #expect(fold("ÁÀÂÃÉÊÍÓÔÕÚÇ") == "aaaaeeiooouc")
    }
}
