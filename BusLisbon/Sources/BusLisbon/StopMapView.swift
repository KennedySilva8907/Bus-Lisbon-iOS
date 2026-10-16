import MapKit
import SwiftUI
import UIKit
import BusLisbonCore

final class SelectedStopAnnotation: MKPointAnnotation {}

final class BusAnnotation: MKPointAnnotation {
    var bearing: Double = 0
}

enum Paint {
    static let yellow = RGB(red: 1, green: 0.8, blue: 0)
    static let ink = RGB(red: 0.102, green: 0.102, blue: 0.102)
    static let white = RGB(red: 1, green: 1, blue: 1)
    static let red = RGB(red: 0.898, green: 0.224, blue: 0.208)
}

private extension CGContext {
    func setFill(_ colour: RGB, alpha: Double = 1) {
        setFillColor(red: colour.red, green: colour.green, blue: colour.blue, alpha: alpha)
    }

    func setStroke(_ colour: RGB, alpha: Double = 1) {
        setStrokeColor(red: colour.red, green: colour.green, blue: colour.blue, alpha: alpha)
    }
}

private func drawRings(
    _ renderer: MKOverlayRenderer,
    at points: [MKMapPoint],
    radius: Double,
    stroke: Double,
    fill: RGB,
    fillAlpha: Double,
    edge: RGB,
    in context: CGContext
) {
    let edges = CGMutablePath()
    let fills = CGMutablePath()
    let outer = radius + stroke

    for point in points {
        edges.addEllipse(in: renderer.rect(for: MKMapRect(x: point.x - outer, y: point.y - outer, width: outer * 2, height: outer * 2)))
        fills.addEllipse(in: renderer.rect(for: MKMapRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)))
    }

    context.setFill(edge)
    context.addPath(edges)
    context.fillPath()

    context.setFill(fill, alpha: fillAlpha)
    context.addPath(fills)
    context.fillPath()
}

private func boundingRect(_ points: [MKMapPoint]) -> MKMapRect {
    points.reduce(MKMapRect.null) { $0.union(MKMapRect(origin: $1, size: MKMapSize(width: 0, height: 0))) }
}

final class StopsOverlay: NSObject, MKOverlay {
    let stops: [Stop]
    let points: [MKMapPoint]
    let muted: Bool
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect

    init(stops: [Stop], muted: Bool) {
        self.stops = stops
        self.muted = muted
        points = stops.map { MKMapPoint(CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)) }
        boundingMapRect = boundingRect(points)
        coordinate = MKMapPoint(x: boundingMapRect.midX, y: boundingMapRect.midY).coordinate
    }

    func nearest(to point: MKMapPoint, within distance: Double) -> Stop? {
        var best: (index: Int, distance: Double)?
        for (index, candidate) in points.enumerated() {
            let dx = candidate.x - point.x
            let dy = candidate.y - point.y
            let squared = dx * dx + dy * dy
            if squared <= distance * distance, squared < (best?.distance ?? .infinity) {
                best = (index, squared)
            }
        }
        return best.map { stops[$0.index] }
    }
}

final class StopsRenderer: MKOverlayRenderer {
    private let points: [MKMapPoint]
    private let muted: Bool

    init(stops overlay: StopsOverlay) {
        points = overlay.points
        muted = overlay.muted
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let zoom = mapZoom(zoomScale: Double(zoomScale))
        let unit = 1 / Double(zoomScale)
        let radius = (muted ? MapStyle.mutedStopRadius : MapStyle.stopRadius).at(zoom) * unit
        let stroke = (muted ? MapStyle.mutedStopStroke : MapStyle.stopStroke).at(zoom) * unit
        let reach = mapRect.insetBy(dx: -(radius + stroke) * 2, dy: -(radius + stroke) * 2)

        drawRings(
            self,
            at: points.filter { reach.contains($0) },
            radius: radius,
            stroke: stroke,
            fill: Paint.yellow,
            fillAlpha: 0.9,
            edge: Paint.ink,
            in: context
        )
    }
}

final class RouteOverlay: NSObject, MKOverlay {
    let points: [MKMapPoint]
    let stops: [MKMapPoint]
    let colour: RGB
    let textColour: RGB
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect

    init(route: Route) {
        points = route.points.map { MKMapPoint(CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)) }
        stops = route.stops.map { MKMapPoint(CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)) }
        colour = rgb(hex: route.colour) ?? Paint.red
        textColour = rgb(hex: route.textColour) ?? Paint.white
        boundingMapRect = boundingRect(points + stops)
        coordinate = MKMapPoint(x: boundingMapRect.midX, y: boundingMapRect.midY).coordinate
    }
}

final class RouteRenderer: MKOverlayRenderer {
    private let route: RouteOverlay

    init(route overlay: RouteOverlay) {
        route = overlay
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard route.points.count > 1 else { return }

        let zoom = mapZoom(zoomScale: Double(zoomScale))
        let unit = 1 / Double(zoomScale)
        let casing = MapStyle.routeCasing.at(zoom) * unit
        let reach = mapRect.insetBy(dx: -casing * 4, dy: -casing * 4)

        let line = CGMutablePath()
        line.move(to: point(for: route.points[0]))
        route.points.dropFirst().forEach { line.addLine(to: point(for: $0)) }

        context.setLineCap(.round)
        context.setLineJoin(.round)

        context.setStroke(Paint.white)
        context.setLineWidth(casing)
        context.addPath(line)
        context.strokePath()

        context.setStroke(route.colour)
        context.setLineWidth(MapStyle.routeLine.at(zoom) * unit)
        context.addPath(line)
        context.strokePath()

        drawArrows(spacing: MapStyle.arrowSpacing.at(zoom) * unit, size: MapStyle.arrowSize.at(zoom) * unit, reach: reach, in: context)
    }

    private func drawArrows(spacing: Double, size: Double, reach: MKMapRect, in context: CGContext) {
        guard spacing > 0 else { return }

        let arrows = CGMutablePath()
        var carried = spacing / 2

        for (from, to) in zip(route.points, route.points.dropFirst()) {
            let dx = to.x - from.x
            let dy = to.y - from.y
            let length = (dx * dx + dy * dy).squareRoot()
            guard length > 0 else { continue }

            var along = carried
            while along < length {
                let at = MKMapPoint(x: from.x + dx * along / length, y: from.y + dy * along / length)
                if reach.contains(at) {
                    let centre = point(for: at)
                    let turn = CGAffineTransform(translationX: centre.x, y: centre.y).rotated(by: atan2(dy, dx))
                    let corners = [(0.14, 0.06), (0.9, 0.5), (0.14, 0.94)].map { corner in
                        CGPoint(x: (corner.0 - 0.5) * size, y: (corner.1 - 0.5) * size).applying(turn)
                    }
                    arrows.addLines(between: corners)
                    arrows.closeSubpath()
                }
                along += spacing
            }
            carried = along - length
        }

        context.setFill(Paint.white, alpha: 0.8)
        context.addPath(arrows)
        context.fillPath()
    }
}

final class RouteStopsOverlay: NSObject, MKOverlay {
    let points: [MKMapPoint]
    let colour: RGB
    let textColour: RGB
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect

    init(route: RouteOverlay) {
        points = route.stops
        colour = route.colour
        textColour = route.textColour
        boundingMapRect = boundingRect(points)
        coordinate = MKMapPoint(x: boundingMapRect.midX, y: boundingMapRect.midY).coordinate
    }
}

final class RouteStopsRenderer: MKOverlayRenderer {
    private let stops: RouteStopsOverlay

    init(stops overlay: RouteStopsOverlay) {
        stops = overlay
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let zoom = mapZoom(zoomScale: Double(zoomScale))
        let unit = 1 / Double(zoomScale)
        let radius = MapStyle.waypointRadius.at(zoom) * unit
        let stroke = MapStyle.waypointStroke.at(zoom) * unit
        let reach = mapRect.insetBy(dx: -(radius + stroke) * 2, dy: -(radius + stroke) * 2)

        drawRings(
            self,
            at: stops.points.filter { reach.contains($0) },
            radius: radius,
            stroke: stroke,
            fill: stops.textColour,
            fillAlpha: 1,
            edge: stops.colour,
            in: context
        )
    }
}

enum PanelCover: Equatable {
    case none, open, closed
}

private struct FrameKey: Equatable {
    let stopId: String?
    let busLat: Double?
    let busLon: Double?
    let panel: PanelCover
    let token: Int
}

final class BusView: MKAnnotationView {
    private let glow = UIImageView(image: MapPalette.busGlow)
    private let body = UIImageView(image: MapPalette.busMarker)

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 88, height: 88)
        glow.center = CGPoint(x: 44, y: 44)
        body.center = CGPoint(x: 44, y: 44)
        addSubview(glow)
        addSubview(body)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(bearing: Double, zoom: Double) {
        let size = MapStyle.vehicleSize.at(zoom)
        body.transform = CGAffineTransform(rotationAngle: bearing * .pi / 180).scaledBy(x: size, y: size)
        let glowScale = MapStyle.vehicleGlowRadius.at(zoom) / 44
        glow.transform = CGAffineTransform(scaleX: glowScale, y: glowScale)
    }
}

@MainActor
enum MapPalette {
    static let busMarker: UIImage? = Bundle.module.url(forResource: "bus-marker", withExtension: "png")
        .flatMap { try? Data(contentsOf: $0) }
        .flatMap { UIImage(data: $0, scale: 3) }

    static let busGlow: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 88, height: 88)).image { context in
        let colours = [
            UIColor(red: 1, green: 0.8, blue: 0, alpha: 0.32).cgColor,
            UIColor(red: 1, green: 0.8, blue: 0, alpha: 0).cgColor,
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours, locations: [0, 1]) else { return }
        context.cgContext.drawRadialGradient(
            gradient,
            startCenter: CGPoint(x: 44, y: 44),
            startRadius: 0,
            endCenter: CGPoint(x: 44, y: 44),
            endRadius: 44,
            options: []
        )
    }

    static let pinAnchor: CGFloat = 62

    static let selectedPin: UIImage = {
        let pin = Bundle.module.url(forResource: "stop-pin", withExtension: "png")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { UIImage(data: $0, scale: 6) }
        let pinSize = pin?.size ?? CGSize(width: 48, height: pinAnchor)
        let dotRadius: CGFloat = 8
        let size = CGSize(width: pinSize.width, height: pinAnchor + dotRadius + 2)

        return UIGraphicsImageRenderer(size: size).image { _ in
            let dot = UIBezierPath(ovalIn: CGRect(
                x: size.width / 2 - dotRadius,
                y: pinAnchor - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            ))
            dot.lineWidth = 2
            UIColor.white.setFill()
            UIColor(white: 0.1, alpha: 1).setStroke()
            dot.fill()
            dot.stroke()
            pin?.draw(in: CGRect(origin: .zero, size: pinSize))
        }
    }()
}

struct StopMapView: UIViewRepresentable {
    let stops: [Stop]
    let selectedStop: Stop?
    let following: Bool
    let bus: BusPosition?
    let route: Route?
    let panel: PanelCover
    let fitToken: Int
    let onSelectStop: (Stop) -> Void

    func makeCoordinator() -> MapCoordinator {
        MapCoordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.pointOfInterestFilter = .excludingAll
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 38.7223, longitude: -9.1393),
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            ),
            animated: false
        )
        context.coordinator.locationManager.requestWhenInUseAuthorization()
        _ = MapPalette.selectedPin
        _ = MapPalette.busMarker
        _ = MapPalette.busGlow

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(MapCoordinator.tapped(_:)))
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)

        let tracking = MKUserTrackingButton(mapView: map)
        tracking.translatesAutoresizingMaskIntoConstraints = false
        tracking.backgroundColor = .systemBackground
        tracking.layer.cornerRadius = 10
        tracking.clipsToBounds = true
        map.addSubview(tracking)
        NSLayoutConstraint.activate([
            tracking.trailingAnchor.constraint(equalTo: map.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            tracking.bottomAnchor.constraint(equalTo: map.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            tracking.widthAnchor.constraint(equalToConstant: 44),
            tracking.heightAnchor.constraint(equalToConstant: 44),
        ])

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onSelectStop = onSelectStop
        coordinator.show(stops: stops, muted: following, on: map)
        coordinator.show(selected: selectedStop, on: map)
        coordinator.show(route: route, on: map)
        coordinator.show(bus: bus, on: map)
        coordinator.frame(stop: selectedStop, bus: bus, panel: panel, token: fitToken, on: map)
    }
}

@MainActor
final class MapCoordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
    let locationManager = CLLocationManager()
    var onSelectStop: (Stop) -> Void = { _ in }

    private var stopsOverlay: StopsOverlay?
    private var routeOverlay: RouteOverlay?
    private var routeStopsOverlay: RouteStopsOverlay?
    private var shownRoute: Route?
    private var selectedId: String?
    private let selectedMarker = SelectedStopAnnotation()
    private let busMarker = BusAnnotation()
    private var busShown = false
    private var framedKey: FrameKey?

    func show(stops: [Stop], muted: Bool, on map: MKMapView) {
        guard !stops.isEmpty else { return }
        if let stopsOverlay, stopsOverlay.muted == muted { return }

        let next = StopsOverlay(stops: stops, muted: muted)
        map.insertOverlay(next, at: 0, level: .aboveLabels)
        if let stopsOverlay { map.removeOverlay(stopsOverlay) }
        stopsOverlay = next
    }

    func show(selected stop: Stop?, on map: MKMapView) {
        guard stop?.id != selectedId else { return }
        selectedId = stop?.id
        map.removeAnnotation(selectedMarker)
        guard let stop else { return }

        selectedMarker.coordinate = CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon)
        map.addAnnotation(selectedMarker)
    }

    func show(route: Route?, on map: MKMapView) {
        guard route != shownRoute else { return }
        shownRoute = route

        if let routeOverlay { map.removeOverlay(routeOverlay) }
        if let routeStopsOverlay { map.removeOverlay(routeStopsOverlay) }
        routeOverlay = nil
        routeStopsOverlay = nil

        guard let route, route.points.count > 1 else { return }

        let overlay = RouteOverlay(route: route)
        let stops = RouteStopsOverlay(route: overlay)
        map.addOverlay(overlay, level: .aboveRoads)
        map.addOverlay(stops, level: .aboveLabels)
        routeOverlay = overlay
        routeStopsOverlay = stops
    }

    func show(bus: BusPosition?, on map: MKMapView) {
        guard let bus else {
            if busShown {
                map.removeAnnotation(busMarker)
                busShown = false
            }
            return
        }

        let target = CLLocationCoordinate2D(latitude: bus.lat, longitude: bus.lon)
        busMarker.bearing = bus.bearing ?? busMarker.bearing

        guard busShown else {
            busMarker.coordinate = target
            map.addAnnotation(busMarker)
            busShown = true
            return
        }

        let from = Coordinate(lat: busMarker.coordinate.latitude, lon: busMarker.coordinate.longitude)
        let to = Coordinate(lat: bus.lat, lon: bus.lon)
        let view = map.view(for: busMarker) as? BusView
        let zoom = currentZoom(of: map)
        let bearing = busMarker.bearing

        if shouldSlide(from: from, to: to) {
            UIView.animate(withDuration: 1) {
                self.busMarker.coordinate = target
                view?.update(bearing: bearing, zoom: zoom)
            }
        } else {
            busMarker.coordinate = target
            view?.update(bearing: bearing, zoom: zoom)
        }
    }

    func frame(stop: Stop?, bus: BusPosition?, panel: PanelCover, token: Int, on map: MKMapView) {
        let key = FrameKey(stopId: stop?.id, busLat: bus?.lat, busLon: bus?.lon, panel: panel, token: token)
        guard key != framedKey else { return }

        let onlyThePanelMoved = framedKey.map {
            FrameKey(stopId: $0.stopId, busLat: $0.busLat, busLon: $0.busLon, panel: panel, token: $0.token) == key
        } ?? false
        framedKey = key

        guard let stop else { return }

        guard onlyThePanelMoved else {
            applyFrame(stop: stop, bus: bus, panel: panel, on: map)
            return
        }

        Task { @MainActor [weak self, weak map] in
            try? await Task.sleep(for: .milliseconds(340))
            guard let self, let map, self.framedKey == key else { return }
            self.applyFrame(stop: stop, bus: bus, panel: panel, on: map)
        }
    }

    private func applyFrame(stop: Stop, bus: BusPosition?, panel: PanelCover, on map: MKMapView) {
        let width = Double(map.bounds.width)
        let height = Double(map.bounds.height)
        guard width > 0, height > 0 else { return }

        let covered: Double = switch panel {
        case .none: 0
        case .open: height * 0.55
        case .closed: 80
        }
        let insets = framePadding(width: width, height: height, covered: covered)
        let target: PlaneRect

        if let bus {
            guard let frame = frameAround([Coordinate(lat: stop.lat, lon: stop.lon), Coordinate(lat: bus.lat, lon: bus.lon)]) else { return }
            let southWest = MKMapPoint(CLLocationCoordinate2D(latitude: frame.southWest.lat, longitude: frame.southWest.lon))
            let northEast = MKMapPoint(CLLocationCoordinate2D(latitude: frame.northEast.lat, longitude: frame.northEast.lon))
            let box = PlaneRect(x: southWest.x, y: northEast.y, width: northEast.x - southWest.x, height: southWest.y - northEast.y)
            target = fittedRect(box, width: width, height: height, insets: insets, maxZoom: frameMaxZoom)
        } else {
            let point = MKMapPoint(CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon))
            let spot = PlaneRect(x: point.x, y: point.y, width: 0, height: 0)
            target = fittedRect(spot, width: width, height: height, insets: insets, maxZoom: frameStopZoom)
        }

        map.setVisibleMapRect(MKMapRect(x: target.x, y: target.y, width: target.width, height: target.height), animated: true)
    }

    private func currentZoom(of map: MKMapView) -> Double {
        guard map.visibleMapRect.width > 0 else { return 15 }
        return mapZoom(zoomScale: Double(map.bounds.width) / map.visibleMapRect.width)
    }

    @objc func tapped(_ tap: UITapGestureRecognizer) {
        guard let map = tap.view as? MKMapView, let stopsOverlay else { return }
        let touch = MKMapPoint(map.convert(tap.location(in: map), toCoordinateFrom: map))
        let mapPointsPerScreenPoint = map.visibleMapRect.width / Double(map.bounds.width)
        if let stop = stopsOverlay.nearest(to: touch, within: 22 * mapPointsPerScreenPoint) {
            onSelectStop(stop)
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        guard busShown, let view = mapView.view(for: busMarker) as? BusView else { return }
        view.update(bearing: busMarker.bearing, zoom: currentZoom(of: mapView))
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
        switch overlay {
        case let route as RouteOverlay:
            return RouteRenderer(route: route)
        case let stops as StopsOverlay:
            return StopsRenderer(stops: stops)
        case let stops as RouteStopsOverlay:
            return RouteStopsRenderer(stops: stops)
        default:
            return MKOverlayRenderer(overlay: overlay)
        }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
        switch annotation {
        case is SelectedStopAnnotation:
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "selected")
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: "selected")
            view.annotation = annotation
            view.image = MapPalette.selectedPin
            view.centerOffset = CGPoint(x: 0, y: MapPalette.selectedPin.size.height / 2 - MapPalette.pinAnchor)
            view.displayPriority = .required
            view.zPriority = .max
            return view
        case is BusAnnotation:
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "bus") as? BusView
                ?? BusView(annotation: annotation, reuseIdentifier: "bus")
            view.annotation = annotation
            view.displayPriority = .required
            view.zPriority = .max
            view.update(bearing: busMarker.bearing, zoom: currentZoom(of: mapView))
            return view
        default:
            return nil
        }
    }
}
