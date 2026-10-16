import Foundation

public let trackReachMetres = 60.0
public let trackBackslideMetres = 30.0
public let trackHoldMetres = 150.0
public let stopMatchMetres = 25.0
let headingReachMetres = 12.0
let headingDisagreement = 100.0

private struct Spot {
    let x: Double
    let y: Double
}

private func project(_ coordinate: Coordinate) -> Spot {
    let sine = sin(coordinate.lat * .pi / 180)
    return Spot(x: (coordinate.lon + 180) / 360, y: 0.5 - log((1 + sine) / (1 - sine)) / (4 * .pi))
}

private func unproject(_ spot: Spot) -> Coordinate {
    Coordinate(lat: atan(sinh(.pi * (1 - 2 * spot.y))) * 180 / .pi, lon: spot.x * 360 - 180)
}

private func compass(from a: Spot, to b: Spot) -> Double {
    let degrees = atan2(b.x - a.x, a.y - b.y) * 180 / .pi
    return degrees < 0 ? degrees + 360 : degrees
}

public func turn(between a: Double, and b: Double) -> Double {
    let difference = abs(a - b).truncatingRemainder(dividingBy: 360)
    return min(difference, 360 - difference)
}

public struct RouteTrack: Sendable {
    private let spots: [Spot]
    private let distances: [Double]
    private let metresPerUnit: Double
    public let length: Double

    public init?(_ points: [Coordinate]) {
        guard points.count > 1 else { return nil }
        let latitude = points.map(\.lat).reduce(0, +) / Double(points.count)
        let scale = 40_075_016.686 * cos(latitude * .pi / 180)
        let spots = points.map(project)
        var running = [0.0]

        for (a, b) in zip(spots, spots.dropFirst()) {
            running.append(running[running.count - 1] + hypot(b.x - a.x, b.y - a.y) * scale)
        }

        self.spots = spots
        distances = running
        metresPerUnit = scale
        length = running[running.count - 1]
    }

    public func locate(_ coordinate: Coordinate, after hint: Double? = nil, heading: Double? = nil) -> Double? {
        let point = project(coordinate)
        var passes: [(along: Double, offset: Double, heading: Double)] = []
        var inPass = false

        for index in spots.indices.dropLast() {
            let a = spots[index]
            let b = spots[index + 1]
            let dx = b.x - a.x
            let dy = b.y - a.y
            let squared = dx * dx + dy * dy
            let t = squared > 0 ? min(1, max(0, ((point.x - a.x) * dx + (point.y - a.y) * dy) / squared)) : 0
            let offset = hypot(a.x + dx * t - point.x, a.y + dy * t - point.y) * metresPerUnit

            guard offset <= trackReachMetres else {
                inPass = false
                continue
            }

            let candidate = (along: distances[index] + (distances[index + 1] - distances[index]) * t, offset: offset, heading: compass(from: a, to: b))
            if !inPass {
                passes.append(candidate)
            } else if offset < passes[passes.count - 1].offset {
                passes[passes.count - 1] = candidate
            }
            inPass = true
        }

        if let hint {
            if let forward = passes.first(where: { $0.along >= hint - trackBackslideMetres }) {
                return forward.along
            }
        } else if let heading {
            let agreeing = passes.filter { turn(between: $0.heading, and: heading) <= headingDisagreement }
            if !agreeing.isEmpty { passes = agreeing }
        }

        return passes.min { $0.offset < $1.offset }?.along
    }

    public func coordinate(at along: Double) -> Coordinate {
        unproject(spot(at: along))
    }

    public func heading(at along: Double) -> Double {
        compass(from: spot(at: along - headingReachMetres), to: spot(at: along + headingReachMetres))
    }

    public func fraction(at along: Double) -> Double {
        length > 0 ? min(1, max(0, along / length)) : 0
    }

    public func arrowSpots(from start: Double, to end: Double, every spacing: Double, clearing stops: [Double], by clearance: Double, bendLimit: Double = 25) -> [Double] {
        guard spacing > 0, end > start else { return [] }
        var found: [Double] = []
        var along = ((max(0, start) / spacing).rounded(.down) + 1) * spacing

        while along < min(end, length) {
            let clearOfStops = !stops.contains { abs($0 - along) < clearance }
            let before = compass(from: spot(at: along - clearance), to: spot(at: along))
            let after = compass(from: spot(at: along), to: spot(at: along + clearance))
            if clearOfStops, turn(between: before, and: after) <= bendLimit {
                found.append(along)
            }
            along += spacing
        }

        return found
    }

    private func spot(at along: Double) -> Spot {
        let clamped = min(max(along, 0), length)
        var low = 0
        var high = distances.count - 1

        while high - low > 1 {
            let middle = (low + high) / 2
            if distances[middle] <= clamped { low = middle } else { high = middle }
        }

        let span = distances[high] - distances[low]
        let t = span > 0 ? (clamped - distances[low]) / span : 0
        return Spot(x: spots[low].x + (spots[high].x - spots[low].x) * t, y: spots[low].y + (spots[high].y - spots[low].y) * t)
    }
}

public struct FollowedRoute: Sendable {
    public let track: RouteTrack
    public let stops: [Coordinate]
    public let stopAlongs: [Double?]

    public init?(_ route: Route) {
        guard let track = RouteTrack(route.points) else { return nil }
        var hint: Double?

        self.track = track
        stops = route.stops
        stopAlongs = route.stops.map { stop in
            let along = track.locate(stop, after: hint)
            hint = along ?? hint
            return along
        }
    }

    public func along(ofStop stop: Coordinate, after bus: Double?) -> Double? {
        let matches = zip(stops, stopAlongs).compactMap { metres($0.0, stop) <= stopMatchMetres ? $0.1 : nil }
        if let bus, let next = matches.first(where: { $0 >= bus - trackBackslideMetres }) {
            return next
        }
        return matches.first ?? track.locate(stop, after: bus)
    }

    public func passed(_ index: Int, bus: Double?) -> Bool {
        guard let bus, let along = stopAlongs[index] else { return false }
        return along < bus
    }
}

public enum TrackMove: Sendable, Equatable {
    case glide(from: Double, to: Double)
    case hold
    case jump(to: Double)
}

public func nextMove(from current: Double?, to fresh: Double) -> TrackMove {
    guard let current else { return .jump(to: fresh) }
    if fresh >= current, fresh - current <= slideLimitMetres { return .glide(from: current, to: fresh) }
    if fresh < current, current - fresh <= trackHoldMetres { return .hold }
    return .jump(to: fresh)
}
