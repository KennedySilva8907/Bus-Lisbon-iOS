import Foundation

public struct Stop: Sendable, Equatable, Codable, Identifiable {
    public let id: String
    public let name: String
    public let lat: Double
    public let lon: Double
    public let locality: String?
    public let lines: [String]

    public init(id: String, name: String, lat: Double, lon: Double, locality: String? = nil, lines: [String] = []) {
        self.id = id
        self.name = name
        self.lat = lat
        self.lon = lon
        self.locality = locality
        self.lines = lines
    }

    enum CodingKeys: String, CodingKey {
        case id, name, lat, lon, locality, lines
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        guard let id = container.decodeTextIfPresent(forKey: .id),
              let name = container.decodeTextIfPresent(forKey: .name),
              let lat = container.decodeNumberIfPresent(forKey: .lat),
              let lon = container.decodeNumberIfPresent(forKey: .lon),
              lat.isFinite, lon.isFinite, lat != 0 || lon != 0 else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "A stop without an id, a name or a position")
            )
        }

        self.init(
            id: id,
            name: name,
            lat: lat,
            lon: lon,
            locality: container.decodeTextIfPresent(forKey: .locality),
            lines: (try? container.decodeIfPresent([String].self, forKey: .lines)) ?? []
        )
    }
}
