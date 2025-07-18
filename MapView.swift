// filepath: MapView.swift

import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var searchManager = MapSearchManager()
    @StateObject private var directionsManager = DirectionsManager()
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var annotations: [MapAnnotation] = []
    @State private var selectedAnnotation: MapAnnotation?
    @State private var searchText = ""
    @State private var showingSearch = false
    @State private var mapType: MKMapType = .standard
    @State private var showsTraffic = false
    @State private var showsBuildings = true
    @State private var showingRouteDetails = false
    
    var body: some View {
        ZStack {
            MapContainer(
                region: $region,
                annotations: $annotations,
                selectedAnnotation: $selectedAnnotation,
                mapType: $mapType,
                showsTraffic: $showsTraffic,
                currentRoute: directionsManager.currentRoute
            )
            .ignoresSafeArea()
            
            VStack {
                if showingSearch {
                    MapSearchBar(
                        searchText: $searchText,
                        searchResults: $searchManager.searchResults,
                        isSearching: searchManager.isSearching,
                        onSearch: { query in
                            searchManager.search(for: query, in: region)
                        },
                        onSelectResult: { mapItem in
                            selectSearchResult(mapItem)
                        }
                    )
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 8)
                    .padding()
                }
                
                Spacer()
                
                HStack {
                    VStack(spacing: 12) {
                        Button(action: {
                            showingSearch.toggle()
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .accessibilityLabel("Search")
                        .mapControlStyle()
                        
                        Button(action: goToCurrentLocation) {
                            Image(systemName: "location.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .accessibilityLabel("Current Location")
                        .mapControlStyle()
                        
                        Menu {
                            Button("Standard") { mapType = .standard }
                            Button("Satellite") { mapType = .satellite }
                            Button("Hybrid") { mapType = .hybrid }
                        } label: {
                            Image(systemName: "map")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .accessibilityLabel("Map Type")
                        .mapControlStyle()
                        
                        Button(action: { showsTraffic.toggle() }) {
                            Image(systemName: showsTraffic ? "car.fill" : "car")
                                .font(.title2)
                                .foregroundColor(showsTraffic ? .red : .blue)
                        }
                        .accessibilityLabel("Traffic")
                        .mapControlStyle()
                    }
                    
                    Spacer()
                }
                .padding()
            }
            
            if let annotation = selectedAnnotation {
                VStack {
                    Spacer()
                    
                    MapAnnotationCallout(
                        annotation: annotation,
                        onGetDirections: {
                            getDirections(to: annotation)
                        },
                        onClose: {
                            selectedAnnotation = nil
                        }
                    )
                    .padding()
                }
            }
            
            if let route = directionsManager.currentRoute, showingRouteDetails {
                VStack {
                    RouteDetailsView(
                        route: route,
                        onClose: {
                            showingRouteDetails = false
                        }
                    )
                    .padding()
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            locationManager.requestLocation()
            addSampleAnnotations()
        }
        .onChange(of: locationManager.location) { location in
            if let location = location {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
        }
        .onChange(of: directionsManager.currentRoute) { route in
            if route != nil {
                showingRouteDetails = true
            }
        }
    }
    
    private func goToCurrentLocation() {
        locationManager.startUpdatingLocation()
    }
    
    private func selectSearchResult(_ mapItem: MKMapItem) {
        let annotation = MapAnnotation(
            id: UUID(),
            title: mapItem.name ?? "Unknown",
            subtitle: mapItem.placemark.title,
            coordinate: mapItem.placemark.coordinate,
            type: .pin,
            color: .red,
            userData: nil
        )
        
        annotations.append(annotation)
        selectedAnnotation = annotation
        
        region = MKCoordinateRegion(
            center: mapItem.placemark.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        showingSearch = false
    }
    
    private func getDirections(to annotation: MapAnnotation) {
        guard let currentLocation = locationManager.location else { return }
        
        directionsManager.calculateRoute(
            from: currentLocation.coordinate,
            to: annotation.coordinate
        )
    }
    
    private func addSampleAnnotations() {
        let sampleAnnotations = [
            MapAnnotation(
                id: UUID(),
                title: "Golden Gate Bridge",
                subtitle: "San Francisco Landmark",
                coordinate: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783),
                type: .pin,
                color: .orange,
                userData: nil
            ),
            MapAnnotation(
                id: UUID(),
                title: "Alcatraz Island",
                subtitle: "Historic Prison",
                coordinate: CLLocationCoordinate2D(latitude: 37.8267, longitude: -122.4233),
                type: .pin,
                color: .blue,
                userData: nil
            ),
            MapAnnotation(
                id: UUID(),
                title: "Fisherman's Wharf",
                subtitle: "Tourist Attraction",
                coordinate: CLLocationCoordinate2D(latitude: 37.8080, longitude: -122.4177),
                type: .restaurant,
                color: .green,
                userData: nil
            )
        ]
        
        annotations = sampleAnnotations
    }
}

struct MapContainer: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var annotations: [MapAnnotation]
    @Binding var selectedAnnotation: MapAnnotation?
    @Binding var mapType: MKMapType
    @Binding var showsTraffic: Bool
    let currentRoute: RouteInfo?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.isRotateEnabled = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(context.coordinator.handleTap)
        )
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.mapType = mapType
        mapView.showsTraffic = showsTraffic
        
        if mapView.region.center.latitude != region.center.latitude ||
           mapView.region.center.longitude != region.center.longitude {
            mapView.setRegion(region, animated: true)
        }
        
        updateAnnotations(mapView)
        updateRoute(mapView)
    }
    
    private func updateAnnotations(_ mapView: MKMapView) {
        let currentAnnotations = mapView.annotations.compactMap { $0 as? CustomAnnotation }
        let newAnnotations = annotations.map { CustomAnnotation(from: $0) }
        
        let annotationsToRemove = currentAnnotations.filter { current in
            !newAnnotations.contains { $0.id == current.id }
        }
        
        let annotationsToAdd = newAnnotations.filter { new in
            !currentAnnotations.contains { $0.id == new.id }
        }
        
        mapView.removeAnnotations(annotationsToRemove)
        mapView.addAnnotations(annotationsToAdd)
    }
    
    private func updateRoute(_ mapView: MKMapView) {
        let currentOverlays = mapView.overlays
        mapView.removeOverlays(currentOverlays)
        
        if let route = currentRoute {
            mapView.addOverlay(route.polyline)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapContainer
        
        init(_ parent: MapContainer) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let customAnnotation = view.annotation as? CustomAnnotation else { return }
            
            if let annotation = parent.annotations.first(where: { $0.id == customAnnotation.id }) {
                parent.selectedAnnotation = annotation
            }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let customAnnotation = annotation as? CustomAnnotation else { return nil }
            
            let identifier = "CustomAnnotation"
            var view: MKAnnotationView
            
            if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) {
                dequeuedView.annotation = annotation
                view = dequeuedView
            } else {
                view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.canShowCallout = false
            }
            
            view.image = customAnnotation.image
            view.accessibilityLabel = customAnnotation.title
            
            return view
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer()
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            parent.selectedAnnotation = nil
        }
    }
}

struct MapSearchBar: View {
    @Binding var searchText: String
    @Binding var searchResults: [MKMapItem]
    let isSearching: Bool
    let onSearch: (String) -> Void
    let onSelectResult: (MKMapItem) -> Void
    
    var body: some View {
        VStack {
            HStack {
                TextField("Search for places...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        onSearch(searchText)
                    }
                    .accessibilityLabel("Search field")
                
                Button(action: {
                    onSearch(searchText)
                }) {
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                }
                .accessibilityLabel("Search")
            }
            .padding()
            
            if !searchResults.isEmpty {
                List(searchResults, id: \.self) { item in
                    SearchResultRow(item: item) {
                        onSelectResult(item)
                    }
                }
                .frame(maxHeight: 200)
                .listStyle(PlainListStyle())
            }
        }
    }
}

struct SearchResultRow: View {
    let item: MKMapItem
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name ?? "Unknown")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let address = item.placemark.title {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .accessibilityLabel(item.name ?? "Unknown location")
    }
}

struct MapAnnotationCallout: View {
    let annotation: MapAnnotation
    let onGetDirections: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(annotation.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let subtitle = annotation.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Close")
            }
            
            HStack(spacing: 12) {
                Button("Get Directions") {
                    onGetDirections()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Get Directions")
                
                Button("More Info") {
                    // Future implementation
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("More Information")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
    }
}

struct RouteDetailsView: View {
    let route: RouteInfo
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Route Details")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Close")
            }
            
            HStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("Distance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(route.formattedDistance)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading) {
                    Text("Travel Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(route.formattedTime)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            
            if !route.instructions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Turn-by-Turn Directions")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    ForEach(Array(route.instructions.prefix(3).enumerated()), id: \.offset) { index, instruction in
                        HStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                            
                            Text(instruction)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    if route.instructions.count > 3 {
                        Text("... and \(route.instructions.count - 3) more steps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
    }
}

extension View {
    func mapControlStyle() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .clipShape(Circle())
            .shadow(radius: 4)
    }
}

struct MapAnnotation: Identifiable, Codable {
    let id: UUID
    let title: String
    let subtitle: String?
    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType
    let color: Color
    let userData: [String: String]?
    
    enum AnnotationType: String, Codable {
        case pin
        case restaurant
        case gasStation
        case hospital
        case school
        case custom
    }
}

extension CLLocationCoordinate2D: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }
}

extension Color: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let description = try container.decode(String.self)
        
        switch description {
        case "red": self = .red
        case "blue": self = .blue
        case "green": self = .green
        case "orange": self = .orange
        case "purple": self = .purple
        case "yellow": self = .yellow
        default: self = .blue
        }
    }
}

struct RouteInfo: Identifiable {
    let id: UUID
    let route: MKRoute
    let distance: CLLocationDistance
    let expectedTravelTime: TimeInterval
    let instructions: [String]
    let polyline: MKPolyline
    
    var formattedDistance: String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: distance)
    }
    
    var formattedTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: expectedTravelTime) ?? "N/A"
    }
}

class CustomAnnotation: NSObject, MKAnnotation {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let type: MapAnnotation.AnnotationType
    let color: Color
    
    init(from mapAnnotation: MapAnnotation) {
        self.id = mapAnnotation.id
        self.coordinate = mapAnnotation.coordinate
        self.title = mapAnnotation.title
        self.subtitle = mapAnnotation.subtitle
        self.type = mapAnnotation.type
        self.color = mapAnnotation.color
        super.init()
    }
    
    var image: UIImage? {
        let systemName: String
        let tintColor: UIColor
        
        switch type {
        case .pin:
            systemName = "mappin.circle.fill"
            tintColor = UIColor(color)
        case .restaurant:
            systemName = "fork.knife.circle.fill"
            tintColor = .systemOrange
        case .gasStation:
            systemName = "fuelpump.circle.fill"
            tintColor = .systemBlue
        case .hospital:
            systemName = "cross.circle.fill"
            tintColor = .systemRed
        case .school:
            systemName = "building.2.crop.circle.fill"
            tintColor = .systemGreen
        case .custom:
            systemName = "mappin.circle.fill"
            tintColor = UIColor(color)
        }
        
        let configuration = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        return UIImage(systemName: systemName, withConfiguration: configuration)?.withTintColor(tintColor, renderingMode: .alwaysOriginal)
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: Error?
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
    }
    
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocation()
            return
        }
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = error
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startUpdatingLocation()
        }
    }
}

class MapSearchManager: ObservableObject {
    @Published var searchResults: [MKMapItem] = []
    @Published var isSearching = false
    @Published var searchError: Error?
    
    private var currentSearchTask: Task<Void, Never>?
    
    func search(for query: String, in region: MKCoordinateRegion) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        currentSearchTask?.cancel()
        
        currentSearchTask = Task {
            await performSearch(query: query, region: region)
        }
    }
    
    @MainActor
    private func performSearch(query: String, region: MKCoordinateRegion) async {
        isSearching = true
        searchError = nil
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            searchResults = response.mapItems
        } catch {
            searchError = error
            searchResults = []
        }
        
        isSearching = false
    }
}

class DirectionsManager: ObservableObject {
    @Published var currentRoute: RouteInfo?
    @Published var isCalculatingRoute = false
    @Published var routeError: Error?
    
    func calculateRoute(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
        isCalculatingRoute = true
        routeError = nil
        
        let sourcePlacemark = MKPlacemark(coordinate: source)
        let destinationPlacemark = MKPlacemark(coordinate: destination)
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destinationPlacemark)
        request.transportType = .automobile
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        
        directions.calculate { [weak self] response, error in
            DispatchQueue.main.async {
                self?.isCalculatingRoute = false
                
                if let error = error {
                    self?.routeError = error
                    return
                }
                
                guard let route = response?.routes.first else {
                    self?.routeError = NSError(
                        domain: "RouteError",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "No route found"]
                    )
                    return
                }
                
                let instructions = route.steps.compactMap { step in
                    step.instructions.isEmpty ? nil : step.instructions
                }
                
                self?.currentRoute = RouteInfo(
                    id: UUID(),
                    route: route,
                    distance: route.distance,
                    expectedTravelTime: route.expectedTravelTime,
                    instructions: instructions,
                    polyline: route.polyline
                )
            }
        }
    }
    
    func clearRoute() {
        currentRoute = nil
        routeError = nil
    }
}