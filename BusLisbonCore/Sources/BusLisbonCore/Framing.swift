import Foundation

public let frameMargin = 0.0012
public let frameTop = 96.0
public let frameSide = 40.0
public let frameGap = 56.0
public let frameMinView = 140.0
public let frameMaxZoom = 17.0
public let frameStopZoom = 16.0

public struct Frame: Sendable, Equatable {
    public let southWest: Coordinate
    public let northEast: Coordinate
}

public struct Insets: Sendable, Equatable {
    public let top: Double
    public let bottom: Double
    public let left: Double
    public let right: Double

    public init(top: Double, bottom: Double, left: Double, right: Double) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
    }
}

public struct PlaneRect: Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public func frameAround(_ points: [Coordinate]) -> Frame? {
    let usable = points.filter { $0.lat.isFinite && $0.lon.isFinite }
    guard !usable.isEmpty else { return nil }

    let lats = usable.map(\.lat)
    let lons = usable.map(\.lon)

    return Frame(
        southWest: Coordinate(lat: lats.min()! - frameMargin, lon: lons.min()! - frameMargin),
        northEast: Coordinate(lat: lats.max()! + frameMargin, lon: lons.max()! + frameMargin)
    )
}

public func framePadding(width: Double, height: Double, covered: Double) -> Insets {
    let room = max(0, height - frameMinView)
    let bottom = min(covered + frameGap, room)
    let top = min(frameTop, max(0, room - bottom))
    let side = min(frameSide, max(0, ((width - frameMinView) / 2).rounded(.down)))

    return Insets(top: top, bottom: bottom, left: side, right: side)
}

public func fittedRect(_ rect: PlaneRect, width: Double, height: Double, insets: Insets, maxZoom: Double) -> PlaneRect {
    let freeWidth = max(1, width - insets.left - insets.right)
    let freeHeight = max(1, height - insets.top - insets.bottom)
    let fitting = min(freeWidth / max(rect.width, .ulpOfOne), freeHeight / max(rect.height, .ulpOfOne))
    let scale = min(fitting, pow(2, maxZoom - 19))

    return PlaneRect(
        x: rect.x + rect.width / 2 - (insets.left + freeWidth / 2) / scale,
        y: rect.y + rect.height / 2 - (insets.top + freeHeight / 2) / scale,
        width: width / scale,
        height: height / scale
    )
}
