import Foundation

public struct BusPosition: Sendable, Equatable {
    public let id: String
    public let lat: Double
    public let lon: Double
    public let lineId: String?
    public let patternId: String?
    public let bearing: Double?
    public let timestamp: Int?
}

struct GatewayVehicleResponse: Decodable {
    let vehicle: GatewayVehicle
}

struct GatewayVehicle: Decodable {
    let id: String
    let lat: Double
    let lon: Double
    let lineId: String?
    let patternId: String?
    let bearing: Double?
    let timestamp: Int?

    var position: BusPosition {
        BusPosition(id: id, lat: lat, lon: lon, lineId: lineId, patternId: patternId, bearing: bearing, timestamp: timestamp)
    }
}

struct FleetVehicle: Decodable {
    let position: BusPosition?

    enum CodingKeys: String, CodingKey {
        case id, lat, lon, bearing, timestamp
        case lineId = "line_id"
        case patternId = "pattern_id"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        guard let id = container.decodeTextIfPresent(forKey: .id),
              let lat = container.decodeNumberIfPresent(forKey: .lat),
              let lon = container.decodeNumberIfPresent(forKey: .lon) else {
            position = nil
            return
        }

        position = BusPosition(
            id: id,
            lat: lat,
            lon: lon,
            lineId: container.decodeTextIfPresent(forKey: .lineId),
            patternId: container.decodeTextIfPresent(forKey: .patternId),
            bearing: container.decodeNumberIfPresent(forKey: .bearing),
            timestamp: container.decodeNumberIfPresent(forKey: .timestamp).map { Int($0) }
        )
    }
}
