import MapKit
import UIKit
import BusLisbonCore

enum RouteLook {
    static let line: CGFloat = 7
    static let edge: CGFloat = 10
    static let faded: CGFloat = 5
    static let fadedAlpha: CGFloat = 0.35
    static let travelled = RGB(red: 0.58, green: 0.59, blue: 0.62)
    static let edgeShade = 0.62
    static let arrowGap = 110.0
    static let arrowHalfWidth = 2.6
    static let arrowHalfHeight = 1.5
    static let arrowStroke = 1.8
    static let arrowsFromZoom = 13.5
    static let stopClearance = 4.0
    static let glideSeconds = 1.0
}

extension RGB {
    func ui(alpha: CGFloat = 1) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    func shaded(by factor: Double) -> RGB {
        RGB(red: red * factor, green: green * factor, blue: blue * factor)
    }
}

extension Coordinate {
    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

enum RoutePart {
    case travelled, edge, ahead, beyond
}

final class RoutePath: MKPolyline {
    var part = RoutePart.ahead
}

final class RouteProgress: @unchecked Sendable {
    private let lock = NSLock()
    private var current: (bus: Double?, stop: Double?) = (nil, nil)

    var snapshot: (bus: Double?, stop: Double?) {
        lock.withLock { current }
    }

    func update(bus: Double?, stop: Double?) {
        lock.withLock { current = (bus, stop) }
    }
}

class RouteMarks: NSObject, MKOverlay {
    let route: FollowedRoute
    let progress: RouteProgress
    let stopPoints: [MKMapPoint]
    let colour: RGB
    let textColour: RGB
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect

    init(route: FollowedRoute, progress: RouteProgress, points: [MKMapPoint], colour: RGB, textColour: RGB) {
        self.route = route
        self.progress = progress
        self.colour = colour
        self.textColour = textColour
        stopPoints = route.stops.map { MKMapPoint($0.location) }
        boundingMapRect = boundingRect(points + stopPoints)
        coordinate = MKMapPoint(x: boundingMapRect.midX, y: boundingMapRect.midY).coordinate
    }
}

final class RouteArrows: RouteMarks {}

final class RouteStops: RouteMarks {}

final class RouteArrowsRenderer: MKOverlayRenderer {
    private let marks: RouteArrows

    init(arrows overlay: RouteArrows) {
        marks = overlay
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let zoom = mapZoom(zoomScale: Double(zoomScale))
        guard zoom >= RouteLook.arrowsFromZoom else { return }

        let unit = 1 / Double(zoomScale)
        let metresPerPoint = MKMetersPerMapPointAtLatitude(marks.coordinate.latitude) * unit
        let track = marks.route.track
        let progress = marks.progress.snapshot
        let ring = MapStyle.waypointRadius.at(zoom) + MapStyle.waypointStroke.at(zoom) + RouteLook.stopClearance
        let reach = mapRect.insetBy(dx: -12 * unit, dy: -12 * unit)
        let halfWidth = RouteLook.arrowHalfWidth * unit
        let halfHeight = RouteLook.arrowHalfHeight * unit
        let chevrons = CGMutablePath()

        let spots = track.arrowSpots(
            from: progress.bus ?? 0,
            to: progress.stop ?? track.length,
            every: RouteLook.arrowGap * metresPerPoint,
            clearing: marks.route.stopAlongs.compactMap { $0 },
            by: ring * metresPerPoint
        )

        for along in spots {
            let at = MKMapPoint(track.coordinate(at: along).location)
            guard reach.contains(at) else { continue }

            let centre = point(for: at)
            let turn = CGAffineTransform(translationX: centre.x, y: centre.y).rotated(by: track.heading(at: along) * .pi / 180)
            chevrons.move(to: CGPoint(x: -halfWidth, y: halfHeight).applying(turn))
            chevrons.addLine(to: CGPoint(x: 0, y: -halfHeight).applying(turn))
            chevrons.addLine(to: CGPoint(x: halfWidth, y: halfHeight).applying(turn))
        }

        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(RouteLook.arrowStroke * unit)
        context.setStroke(Paint.white)
        context.addPath(chevrons)
        context.strokePath()
    }
}

final class RouteStopsRenderer: MKOverlayRenderer {
    private let marks: RouteStops

    init(stops overlay: RouteStops) {
        marks = overlay
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let zoom = mapZoom(zoomScale: Double(zoomScale))
        let unit = 1 / Double(zoomScale)
        let radius = MapStyle.waypointRadius.at(zoom) * unit
        let stroke = MapStyle.waypointStroke.at(zoom) * unit
        let reach = mapRect.insetBy(dx: -(radius + stroke) * 2, dy: -(radius + stroke) * 2)
        let bus = marks.progress.snapshot.bus
        var passed: [MKMapPoint] = []
        var ahead: [MKMapPoint] = []

        for (index, point) in marks.stopPoints.enumerated() where reach.contains(point) {
            if marks.route.passed(index, bus: bus) {
                passed.append(point)
            } else {
                ahead.append(point)
            }
        }

        drawRings(self, at: passed, radius: radius, stroke: stroke, fill: Paint.white, fillAlpha: 1, edge: RouteLook.travelled, in: context)
        drawRings(self, at: ahead, radius: radius, stroke: stroke, fill: marks.textColour, fillAlpha: 1, edge: marks.colour, in: context)
    }
}
