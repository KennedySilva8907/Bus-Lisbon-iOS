import MapKit
import SwiftUI
import UIKit
import BusLisbonCore

final class StopAnnotation: MKPointAnnotation {
    let stop: Stop

    init(stop: Stop) {
        self.stop = stop
        super.init()
        coordinate = CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon)
    }
}

final class GroupAnnotation: MKPointAnnotation {
    let count: Int

    init(group: StopCluster) {
        count = group.count
        super.init()
        coordinate = CLLocationCoordinate2D(latitude: group.lat, longitude: group.lon)
    }
}

final class SelectedStopAnnotation: MKPointAnnotation {}

@MainActor
enum MapPalette {
    static let yellow = UIColor(red: 1, green: 0.8, blue: 0, alpha: 1)
    static let ink = UIColor(white: 0.1, alpha: 1)

    static let stopDot: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 18, height: 18)).image { _ in
        MapPalette.yellow.setFill()
        MapPalette.ink.setStroke()
        let dot = UIBezierPath(ovalIn: CGRect(x: 1, y: 1, width: 16, height: 16))
        dot.lineWidth = 2
        dot.fill()
        dot.stroke()
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
            MapPalette.ink.setStroke()
            dot.fill()
            dot.stroke()
            pin?.draw(in: CGRect(origin: .zero, size: pinSize))
        }
    }()
}

struct StopMapView: UIViewRepresentable {
    let stops: [Stop]
    let selectedStop: Stop?
    let onSelectStop: (Stop) -> Void

    func makeCoordinator() -> MapCoordinator {
        MapCoordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.pointOfInterestFilter = .excludingAll
        map.setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 38.7223, longitude: -9.1393),
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            ),
            animated: false
        )
        context.coordinator.locationManager.requestWhenInUseAuthorization()
        _ = MapPalette.selectedPin

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
        coordinator.add(stops: stops, to: map)
        coordinator.show(selected: selectedStop, on: map)
    }
}

@MainActor
final class MapCoordinator: NSObject, MKMapViewDelegate {
    let locationManager = CLLocationManager()
    var onSelectStop: (Stop) -> Void = { _ in }

    private var allStops: [Stop] = []
    private var shown: [String: MKPointAnnotation] = [:]
    private var selectedId: String?
    private let selectedMarker = SelectedStopAnnotation()

    func add(stops: [Stop], to map: MKMapView) {
        guard allStops.isEmpty, !stops.isEmpty else { return }
        allStops = stops
        refreshGroups(on: map)
    }

    func show(selected stop: Stop?, on map: MKMapView) {
        guard stop?.id != selectedId else { return }
        selectedId = stop?.id
        map.removeAnnotation(selectedMarker)
        guard let stop else { return }

        selectedMarker.coordinate = CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon)
        map.addAnnotation(selectedMarker)

        let span = map.region.span.latitudeDelta > 0.02
            ? MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            : map.region.span
        let centre = CLLocationCoordinate2D(latitude: stop.lat - span.latitudeDelta * 0.25, longitude: stop.lon)
        map.setRegion(MKCoordinateRegion(center: centre, span: span), animated: true)
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        refreshGroups(on: mapView)
    }

    private func refreshGroups(on map: MKMapView) {
        guard !allStops.isEmpty else { return }

        let region = map.region
        let box = MapBox(
            minLat: region.center.latitude - region.span.latitudeDelta,
            maxLat: region.center.latitude + region.span.latitudeDelta,
            minLon: region.center.longitude - region.span.longitudeDelta,
            maxLon: region.center.longitude + region.span.longitudeDelta
        )
        let groups = clusterStops(
            allStops,
            in: box,
            cellSize: clusterCellSize(span: region.span.latitudeDelta),
            showAllBelow: showStopsBelow
        )
        let wanted = Set(groups.map(\.key))

        let leaving = shown.filter { !wanted.contains($0.key) }
        map.removeAnnotations(Array(leaving.values))
        leaving.keys.forEach { shown[$0] = nil }

        let arriving = groups.filter { shown[$0.key] == nil }
        let annotations: [MKPointAnnotation] = arriving.map { group in
            group.stop.map { StopAnnotation(stop: $0) } ?? GroupAnnotation(group: group)
        }
        zip(arriving, annotations).forEach { shown[$0.key] = $1 }
        map.addAnnotations(annotations)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
        switch annotation {
        case let group as GroupAnnotation:
            let view = marker(for: group, id: "group", on: mapView)
            view.markerTintColor = MapPalette.yellow
            view.glyphTintColor = MapPalette.ink
            view.glyphText = String(group.count)
            view.displayPriority = .required
            view.animatesWhenAdded = true
            return view
        case is StopAnnotation:
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "stop") ?? stopView(for: annotation)
            view.annotation = annotation
            view.image = MapPalette.stopDot
            view.displayPriority = .required
            return view
        case is SelectedStopAnnotation:
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "selected")
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: "selected")
            view.annotation = annotation
            view.image = MapPalette.selectedPin
            view.centerOffset = CGPoint(x: 0, y: MapPalette.selectedPin.size.height / 2 - MapPalette.pinAnchor)
            view.displayPriority = .required
            view.zPriority = .max
            return view
        default:
            return nil
        }
    }

    func mapView(_ mapView: MKMapView, didSelect annotation: any MKAnnotation) {
        if let stop = annotation as? StopAnnotation {
            onSelectStop(stop.stop)
        } else if let group = annotation as? GroupAnnotation {
            let span = mapView.region.span
            mapView.setRegion(
                MKCoordinateRegion(
                    center: group.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: span.latitudeDelta / 4, longitudeDelta: span.longitudeDelta / 4)
                ),
                animated: true
            )
        }
        mapView.deselectAnnotation(annotation, animated: false)
    }

    private func stopView(for annotation: any MKAnnotation) -> MKAnnotationView {
        let view = MKAnnotationView(annotation: annotation, reuseIdentifier: "stop")
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tappedStop(_:))))
        return view
    }

    @objc private func tappedStop(_ tap: UITapGestureRecognizer) {
        guard let stop = (tap.view as? MKAnnotationView)?.annotation as? StopAnnotation else { return }
        onSelectStop(stop.stop)
    }

    private func marker(for annotation: any MKAnnotation, id: String, on map: MKMapView) -> MKMarkerAnnotationView {
        let view = map.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
        view.annotation = annotation
        return view
    }
}
