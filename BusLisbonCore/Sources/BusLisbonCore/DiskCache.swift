import Foundation

public struct DiskCache: Sendable {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func save<Value: Encodable>(_ value: Value, as key: String, now: Date = Date()) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(Envelope(savedAt: now, value: value))
        try data.write(to: file(key), options: .atomic)
    }

    public func load<Value: Decodable>(_ type: Value.Type, key: String, maxAge: TimeInterval?, now: Date = Date()) -> Value? {
        guard let data = try? Data(contentsOf: file(key)),
              let envelope = try? JSONDecoder().decode(Envelope<Value>.self, from: data) else { return nil }

        if let maxAge, now.timeIntervalSince(envelope.savedAt) > maxAge { return nil }

        return envelope.value
    }

    private func file(_ key: String) -> URL {
        directory.appendingPathComponent(Endpoint.segment(key) + ".json")
    }
}

private struct Envelope<Value> {
    let savedAt: Date
    let value: Value
}

extension Envelope: Encodable where Value: Encodable {}
extension Envelope: Decodable where Value: Decodable {}

public let stopsMaxAge: TimeInterval = 86_400

public func loadStops(cache: DiskCache, api: BusLisbonAPI, now: Date = Date()) async -> [Stop]? {
    if let fresh = cache.load([Stop].self, key: "stops", maxAge: stopsMaxAge, now: now) {
        return fresh
    }

    if let fetched = try? await api.stops(), !fetched.isEmpty {
        try? cache.save(fetched, as: "stops", now: now)
        return fetched
    }

    return cache.load([Stop].self, key: "stops", maxAge: nil, now: now)
}
