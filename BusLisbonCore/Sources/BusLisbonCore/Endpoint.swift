import Foundation

enum Endpoint {
    static let backend = "https://ca-buslisbon-api.politeglacier-dcb5b974.spaincentral.azurecontainerapps.io"
    static let carris = "https://api.carrismetropolitana.pt"

    static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    static func segment(_ raw: String) -> String {
        raw.addingPercentEncoding(withAllowedCharacters: unreserved) ?? raw
    }

    static var health: URL { url(backend + "/health") }
    static var stops: URL { url(carris + "/stops") }
    static var fleet: URL { url(carris + "/v2/vehicles") }

    static func board(_ stopId: String) -> URL { url(backend + "/api/arrivals/by-stop/" + segment(stopId)) }
    static func vehicle(_ id: String) -> URL { url(backend + "/api/vehicles/" + segment(id)) }
    static func vehicleOnTrip(_ tripId: String, number: String, lineId: String) -> URL {
        url(backend + "/api/vehicles/by-trip/" + segment(tripId) + "?number=" + segment(number) + "&lineId=" + segment(lineId))
    }

    static func pattern(_ id: String) -> URL { url(carris + "/patterns/" + segment(id)) }
    static func shape(_ id: String) -> URL { url(carris + "/shapes/" + segment(id)) }

    private static func url(_ text: String) -> URL { URL(string: text)! }
}
