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
    @State private var showingRouteInfo = false
    
    var body: some View {
        ZStack {
            MapContainer(
                region: $region,
                annotations: $annotations,
                selectedAnnotation: $selectedAnnotation,
                mapType: $mapType,
                showsTraffic: $showsTraffic,
                showsBuildings: $showsBuildings,
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
                        onSelectResult: { item in
                            selectSearchResult(item)
                        }
                    )
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 8)
                    .padding(.horizontal)
                }
                
                Spacer()
                
                if showingRouteInfo, let route = directionsManager.currentRoute {
                    RouteInfoView(
                        route: route,
                        onClose: {
                            showingRouteInfo = false
                            directionsManager.currentRoute = nil
                        }
                    )
                    .padding()
                }
            }
            
            VStack {
                HStack {
                    Button(action: {
                        showingSearch.toggle()
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(radius: 4)
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                HStack {
                    Spacer()
                    
                    MapControls(
                        mapType: $mapType,
                        showsTraffic: $showsTraffic,
                        showsBuildings: $showsBuildings,
                        onLocationTap: {
                            goToCurrentLocation()
                        }
                    )
                    .padding()
                }
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
            
            if directionsManager.isCalculatingRoute {
                ProgressView("Calculating route...")
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 8)
            }
        }
        .onAppear {
            locationManager.requestLocation()
            setupDefaultAnnotations()
        }
        .onChange(of: locationManager.location) { location in
            if let location = location {
                region.center = location.coordinate
            }
        }
        .onChange(of: directionsManager.currentRoute) { route in
            if route != nil {
                showingRouteInfo = true
            }
        }
        .accessibilityLabel("Interactive map view")
    }
    
    private func goToCurrentLocation() {
        if let location = locationManager.location {
            withAnimation(.easeInOut(duration: 1.0)) {
                region.center = location.coordinate
                region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            }
        } else {
            locationManager.requestLocation()
        }
    }
    
    private func selectSearchResult(_ item: MKMapItem) {
        let annotation = MapAnnotation(
            id: UUID(),
            title: item.name ?? "Unknown",
            subtitle: item.placemark.title,
            coordinate: item.placemark.coordinate,
            type: .pin,
            color: .red,
            userData: nil
        )
        
        annotations.append(annotation)
        selectedAnnotation = annotation
        
        withAnimation(.easeInOut(duration: 1.0)) {
            region.center = item.placemark.coordinate
        }
        
        showingSearch = false
    }
    
    private func getDirections(to annotation: MapAnnotation) {
        guard let userLocation = locationManager.location else {
            return
        }
        
        directionsManager.calculateRoute(
            from: userLocation.coordinate,
            to: annotation.coordinate
        )
    }
    
    private func setupDefaultAnnotations() {
        let defaultAnnotations = [
            MapAnnotation(
                id: UUID(),
                title: "Golden Gate Bridge",
                subtitle: "San Francisco Landmark",
                coordinate: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783),
                type: .pin,
                color: .red,
                userData: nil
            ),
            MapAnnotation(
                id: UUID(),
                title: "Lombard Street",
                subtitle: "Most Crooked Street",
                coordinate: CLLocationCoordinate2D(latitude: 37.8021, longitude: -122.4187),
                type: .pin,
                color: .blue,
                userData: nil
            ),
            MapAnnotation(
                id: UUID(),
                title: "Pier 39",
                subtitle: "Tourist Attraction",
                coordinate: CLLocationCoordinate2D(latitude: 37.8087, longitude: -122.4098),
                type: .restaurant,
                color: .green,
                userData: nil
            )
        ]
        
        annotations = defaultAnnotations
    }
}

struct MapContainer: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var annotations: [MapAnnotation]
    @Binding var selectedAnnotation: MapAnnotation?
    @Binding var mapType: MKMapType
    @Binding var showsTraffic: Bool
    @Binding var showsBuildings: Bool
    let currentRoute: RouteInfo?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.isRotateEnabled = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = true
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.mapType = mapType
        mapView.showsTraffic = showsTraffic
        mapView.showsBuildings = showsBuildings
        
        if mapView.region.center.latitude != region.center.latitude ||
           mapView.region.center.longitude != region.center.longitude {
            mapView.setRegion(region, animated: true)
        }
        
        let currentAnnotations = mapView.annotations.compactMap { $0 as? MKPointAnnotation }
        let newAnnotations = annotations.map { annotation in
            let mkAnnotation = MKPointAnnotation()
            mkAnnotation.coordinate = annotation.coordinate
            mkAnnotation.title = annotation.title
            mkAnnotation.subtitle = annotation.subtitle
            return mkAnnotation
        }
        
        mapView.removeAnnotations(currentAnnotations)
        mapView.addAnnotations(newAnnotations)
        
        if let route = currentRoute {
            mapView.removeOverlays(mapView.overlays)
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
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation as? MKPointAnnotation else { return }
            
            if let selectedAnnotation = parent.annotations.first(where: { mapAnnotation in
                mapAnnotation.coordinate.latitude == annotation.coordinate.latitude &&
                mapAnnotation.coordinate.longitude == annotation.coordinate.longitude
            }) {
                parent.selectedAnnotation = selectedAnnotation
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
}

struct MapSearchBar: View {
    @Binding var searchText: String
    let searchResults: [MKMapItem]
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
                    .accessibilityLabel("Search for places")
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button(action: {
                        onSearch(searchText)
                    }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel("Search")
                }
            }
            .padding()
            
            if !searchResults.isEmpty {
                searchResultsList
            }
        }
    }
    
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(searchResults.prefix(5), id: \.self) { item in
                    SearchResultRow(item: item) {
                        onSelectResult(item)
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(maxHeight: 200)
    }
}

struct SearchResultRow: View {
    let item: MKMapItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(item.name ?? "Unknown location")")
    }
}

struct MapControls: View {
    @Binding var mapType: MKMapType
    @Binding var showsTraffic: Bool
    @Binding var showsBuildings: Bool
    let onLocationTap: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: onLocationTap) {
                Image(systemName: "location.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color.white)
            .clipShape(Circle())
            .shadow(radius: 4)
            .accessibilityLabel("Go to current location")
            
            Menu {
                Button("Standard") { mapType = .standard }
                Button("Satellite") { mapType = .satellite }
                Button("Hybrid") { mapType = .hybrid }
            } label: {
                Image(systemName: "map")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color.white)
            .clipShape(Circle())
            .shadow(radius: 4)
            .accessibilityLabel("Map type")
            
            Button(action: { showsTraffic.toggle() }) {
                Image(systemName: showsTraffic ? "car.fill" : "car")
                    .font(.title2)
                    .foregroundColor(showsTraffic ? .red : .blue)
            }
            .padding()
            .background(Color.white)
            .clipShape(Circle())
            .shadow(radius: 4)
            .accessibilityLabel("Toggle traffic")
            
            Button(action: { showsBuildings.toggle() }) {
                Image(systemName: showsBuildings ? "building.fill" : "building")
                    .font(.title2)
                    .foregroundColor(showsBuildings ? .green : .blue)
            }
            .padding()
            .background(Color.white)
            .clipShape(Circle())
            .shadow(radius: 4)
            .accessibilityLabel("Toggle buildings")
        }
    }
}

struct MapAnnotationCallout: View {
    let annotation: MapAnnotation
    let onGetDirections: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(annotation.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let subtitle = annotation.subtitle {
                        Text(subtitle)
                            .font(.caption)
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
                .accessibilityLabel("Get directions to \(annotation.title)")
                
                Button("More Info") {
                    // Show more details
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("More information about \(annotation.title)")
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
    }
}

struct RouteInfoView: View {
    let route: RouteInfo
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Route Information")
                        .font(.headline)
                    
                    HStack {
                        Text(route.formattedDistance)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(route.formattedTime)
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Close route information")
            }
            
            if !route.instructions.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Turn-by-turn directions:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(Array(route.instructions.prefix(3).enumerated()), id: \.offset) { index, instruction in
                            HStack {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(instruction)
                                    .font(.caption)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .frame(maxHeight: 80)
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
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
    
    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, type, userData
        case latitude, longitude
    }
    
    init(id: UUID, title: String, subtitle: String?, coordinate: CLLocationCoordinate2D, type: AnnotationType, color: Color, userData: [String: String]?) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.type = type
        self.color = color
        self.userData = userData
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        type = try container.decode(AnnotationType.self, forKey: .type)
        color = .blue
        userData = try container.decodeIfPresent([String: String].self, forKey: .userData)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(userData, forKey: .userData)
    }
}

struct RouteInfo: Identifiable {
    let id: UUID
    let route: MKRoute
    let distance: CLLocationDistance
    let expectedTravelTime: TimeInterval
    let instructions: [String]
    let polyline: MKPolyline
    
    init(id: UUID, route: MKRoute, distance: CLLocationDistance, expectedTravelTime: TimeInterval, instructions: [String], polyline: MKPolyline) {
        self.id = id
        self.route = route
        self.distance = distance
        self.expectedTravelTime = expectedTravelTime
        self.instructions = instructions
        self.polyline = polyline
    }
    
    var formattedDistance: String {
        let formatter = MKDistanceFormatter()
        return formatter.string(fromDistance: distance)
    }
    
    var formattedTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: expectedTravelTime) ?? "Unknown"
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
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            locationError = NSError(domain: "LocationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Location access denied"])
        @unknown default:
            break
        }
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
            locationManager.startUpdatingLocation()
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
                    self?.routeError = NSError(domain: "RouteError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No route found"])
                    return
                }
                
                self?.currentRoute = RouteInfo(
                    id: UUID(),
                    route: route,
                    distance: route.distance,
                    expectedTravelTime: route.expectedTravelTime,
                    instructions: route.steps.compactMap { step in
                        step.instructions.isEmpty ? nil : step.instructions
                    },
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

extension Color: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let colorName = try container.decode(String.self)
        
        switch colorName {
        case "red":
            self = .red
        case "blue":
            self = .blue
        case "green":
            self = .green
        case "yellow":
            self = .yellow
        case "orange":
            self = .orange
        case "purple":
            self = .purple
        default:
            self = .blue
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("blue")
    }
}