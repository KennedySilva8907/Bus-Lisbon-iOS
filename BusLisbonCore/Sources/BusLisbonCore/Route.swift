import Foundation

public struct Coordinate: Sendable, Equatable, Codable {
    public let lat: Double
    public let lon: Double

    public init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }
}

public struct Route: Sendable, Equatable, Codable {
    public let colour: String
    public let textColour: String
    public let points: [Coordinate]
    public let stops: [Coordinate]
}

struct PatternResponse: Decodable {
    let colour: String?
    let textColour: String?
    let shapeId: String?
    let stops: [Coordinate]

    private struct PathEntry: Decodable {
        let stop: Stop
    }

    enum CodingKeys: String, CodingKey {
        case colour = "color"
        case textColour = "text_color"
        case shapeId = "shape_id"
        case path
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        colour = container.decodeTextIfPresent(forKey: .colour)
        textColour = container.decodeTextIfPresent(forKey: .textColour)
        shapeId = container.decodeTextIfPresent(forKey: .shapeId)
        stops = ((try? container.decodeIfPresent(LossyArray<PathEntry>.self, forKey: .path))?.elements ?? [])
            .map { Coordinate(lat: $0.stop.lat, lon: $0.stop.lon) }
    }
}

struct ShapeResponse: Decodable {
    struct GeoJSON: Decodable {
        let geometry: Geometry
    }

    struct Geometry: Decodable {
        let coordinates: [[Double]]
    }

    let geojson: GeoJSON

    var points: [Coordinate] {
        geojson.geometry.coordinates.compactMap { pair in
            pair.count >= 2 ? Coordinate(lat: pair[1], lon: pair[0]) : nil
        }
    }
}

extension BusLisbonAPI {
    public func route(patternId: String) async throws -> Route? {
        let pattern = try await get(PatternResponse.self, Endpoint.pattern(patternId))
        guard let shapeId = pattern.shapeId else { return nil }
        let shape = try await get(ShapeResponse.self, Endpoint.shape(shapeId))
        return Route(
            colour: pattern.colour ?? "#E53935",
            textColour: pattern.textColour ?? "#FFFFFF",
            points: shape.points,
            stops: pattern.stops
        )
    }
}

public func loadRoute(patternId: String, cache: DiskCache, api: BusLisbonAPI) async -> Route? {
    let key = "route-" + patternId

    if let cached = cache.load(Route.self, key: key, maxAge: nil) {
        return cached
    }

    guard let fetched = try? await api.route(patternId: patternId) else { return nil }
    try? cache.save(fetched, as: key)
    return fetched
}

public struct RGB: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public func rgb(hex: String) -> RGB? {
    let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    guard digits.count == 6, let value = Int(digits, radix: 16) else { return nil }

    return RGB(
        red: Double((value >> 16) & 0xFF) / 255,
        green: Double((value >> 8) & 0xFF) / 255,
        blue: Double(value & 0xFF) / 255
    )
}

public let slideLimitMetres = 500.0

public func metres(_ a: Coordinate, _ b: Coordinate) -> Double {
    let radius = 6_371_000.0
    let radians = Double.pi / 180
    let dLat = (b.lat - a.lat) * radians
    let dLon = (b.lon - a.lon) * radians
    let h = sin(dLat / 2) * sin(dLat / 2)
        + cos(a.lat * radians) * cos(b.lat * radians) * sin(dLon / 2) * sin(dLon / 2)
    return 2 * radius * asin(min(1, sqrt(h)))
}

public func shouldSlide(from: Coordinate, to: Coordinate) -> Bool {
    metres(from, to) <= slideLimitMetres
}
