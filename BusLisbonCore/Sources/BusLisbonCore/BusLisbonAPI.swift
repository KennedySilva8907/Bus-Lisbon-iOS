import Foundation

public enum APIError: Error, Equatable {
    case status(Int)
}

public struct BusLisbonAPI: Sendable {
    public typealias Fetch = @Sendable (URL, TimeInterval) async throws -> (Data, Int)

    static let quick: TimeInterval = 5
    static let patient: TimeInterval = 30

    private let fetch: Fetch

    public init(fetch: @escaping Fetch) {
        self.fetch = fetch
    }

    public func wake() async {
        _ = try? await fetch(Endpoint.health, Self.patient)
    }

    public func stops() async throws -> [Stop] {
        try await get(LossyArray<Stop>.self, Endpoint.stops).elements
    }

    public func board(stopId: String) async throws -> [BoardEntry] {
        try await get([BoardEntry].self, Endpoint.board(stopId))
    }

    public func vehicle(id: String) async throws -> BusPosition? {
        let (data, status) = try await fetch(Endpoint.vehicle(id), Self.quick)
        if status == 404 { return nil }
        guard (200..<300).contains(status) else { throw APIError.status(status) }
        return try JSONDecoder().decode(GatewayVehicleResponse.self, from: data).vehicle.position
    }

    public func fleet() async throws -> [BusPosition] {
        try await get(LossyArray<FleetVehicle>.self, Endpoint.fleet).elements.compactMap(\.position)
    }

    func get<Value: Decodable>(_ type: Value.Type, _ url: URL, timeout: TimeInterval = BusLisbonAPI.patient) async throws -> Value {
        let (data, status) = try await fetch(url, timeout)
        guard (200..<300).contains(status) else { throw APIError.status(status) }
        return try JSONDecoder().decode(Value.self, from: data)
    }
}
