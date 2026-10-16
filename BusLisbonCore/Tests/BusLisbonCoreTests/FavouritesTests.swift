import Testing
@testable import BusLisbonCore

private let index = StopSearchIndex([
    Stop(id: "060161", name: "Estr. Desvio", lat: 38.77, lon: -9.15, locality: "Lisboa"),
    Stop(id: "060162", name: "Rua Angola", lat: 38.79, lon: -9.12, locality: "Olival Basto"),
    Stop(id: "110061", name: "Caneças (Escola Secundária)", lat: 38.81, lon: -9.22, locality: "Odivelas"),
])

struct FavouritesTests {
    @Test func addsANewFavouriteAtTheEnd() {
        #expect(toggled("110061", in: ["060161"]) == ["060161", "110061"])
    }

    @Test func removesAFavouriteThatIsAlreadyThere() {
        #expect(toggled("060161", in: ["060161", "110061"]) == ["110061"])
    }

    @Test func keepsTheOrderTheyWereAdded() {
        #expect(index.stops(withIds: ["110061", "060161"]).map(\.id) == ["110061", "060161"])
    }

    @Test func skipsAFavouriteWhoseStopIsGone() {
        #expect(index.stops(withIds: ["999999", "060162"]).map(\.id) == ["060162"])
    }
}
