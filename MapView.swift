```swift
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
    @State private var showingRoute = false
    
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
                    
                    if showingSearch {
                        MapSearchBar(
                            searchText: $searchText,
                            searchResults: $searchManager.searchResults,
                            isSearching: $searchManager.isSearching
                        ) { item in
                            selectSearchResult(item)
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 4)
                    }
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                HStack {
                    Spacer()
                    
                    MapControls(
                        mapType: $mapType,
                        showsTraffic: $showsTraffic,
                        showsBuildings: $showsBuildings
                    ) {
                        goToCurrentLocation()
                    }
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
            
            if showingRoute, let route = directionsManager.currentRoute {
                VStack {
                    RouteInfoView(
                        route: route,
                        onClose: {
                            showingRoute = false
                            directionsManager.currentRoute = nil
                        }
                    )
                    .padding()
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            locationManager.requestLocation()
            setupSampleAnnotations()
        }
        .onChange(of: searchText) { newValue in
            if !newValue.isEmpty {
                searchManager.search(for: newValue, in: region)
            }
        }
        .onChange(of: locationManager.location) { newLocation in
            if let location = newLocation {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
        }
        .alert("Location Error", isPresented: .constant(locationManager.locationError != nil)) {
            Button("OK") { }
        } message: {
            Text(locationManager.locationError?.localizedDescription ?? "")
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
        
        region = MKCoordinateRegion(
            center: item.placemark.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        showingSearch = false
        searchText = ""
    }
    
    private func getDirections(to annotation: MapAnnotation) {
        guard let currentLocation = locationManager.location else { return }
        
        directionsManager.calculateRoute(
            from: currentLocation.coordinate,
            to: annotation.coordinate
        )
        showingRoute = true
    }
    
    private func goToCurrentLocation() {
        if let location = locationManager.location {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        } else {
            locationManager.requestLocation()
        }
    }
    
    private func setupSampleAnnotations() {
        let sampleAnnotations = [
            MapAnnotation(
                id: UUID(),
                title: "Apple Park",
                subtitle: "Cupertino, CA",
                coordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
                type: .custom,
                color: .blue,
                userData: nil
            ),
            MapAnnotation(
                id: UUID(),
                title: "Golden Gate Bridge",
                subtitle: "San Francisco, CA",
                coordinate: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783),
                type: .custom,
                color: .orange,
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
    @Binding var showsBuildings: Bool
    let currentRoute: RouteInfo?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        mapView.showsCompass = true
        mapView.showsScale = true
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
        mapView.mapType = mapType
        mapView.showsTraffic = showsTraffic
        mapView.showsBuildings = showsBuildings
        
        mapView.removeAnnotations(mapView.annotations)
        let mkAnnotations = annotations.map { annotation in
            let mkAnnotation = MKPointAnnotation()
            mkAnnotation.coordinate = annotation.coordinate
            mkAnnotation.title = annotation.title
            mkAnnotation.subtitle = annotation.subtitle
            return mkAnnotation
        }
        mapView.addAnnotations(mkAnnotations)
        
        mapView.removeOverlays(mapView.overlays)
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
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation as? MKPointAnnotation else { return }
            
            if let mapAnnotation = parent.annotations.first(where: { $0.coordinate.latitude == annotation.coordinate.latitude && $0.coordinate.longitude == annotation.coordinate.longitude }) {
                parent.selectedAnnotation = mapAnnotation
            }
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
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            
            let identifier = "MapAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                annotationView?.animatesWhenAdded = true
            } else {
                annotationView?.annotation = annotation
            }
            
            return annotationView
        }
    }
}

struct MapSearchBar: View {
    @Binding var searchText: String
    @Binding var searchResults: [MKMapItem]
    @Binding var isSearching: Bool
    let onResultSelected: (MKMapItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField("Search for places...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .accessibilityLabel("Search for places")
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            if !searchResults.isEmpty {
                List(searchResults, id: \.self) { item in
                    SearchResultRow(item: item) {
                        onResultSelected(item)
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
            .padding(.vertical, 4)
        }
        .accessibilityLabel(item.name ?? "Unknown location")
    }
}

struct MapControls: View {
    @Binding var mapType: MKMapType
    @Binding var showsTraffic: Bool
    @Binding var showsBuildings: Bool
    let onLocationTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: onLocationTapped) {
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
        }
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
                
                Button("Share") {
                    // Share location
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Share location")
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct RouteInfoView: View {
    let route: RouteInfo
    let onClose: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Route Info")
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
            }
            .accessibilityLabel("Close route info")
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        type = try container.decode(AnnotationType.self, forKey: .type)
        userData = try container.decodeIfPresent([String: String].self, forKey: .userData)
        
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        color = .blue
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(userData, forKey: .userData)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
    }
}

extension CLLocationCoordinate2D: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }
}

extension Color: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let colorName = try container.decode(String.self)
        
        switch colorName {
        case "red": self = .red
        case "blue": self = .blue
        case "green": self = .green
        case "orange": self = .orange
        case "purple": self = .purple
        case "yellow": self = .yellow
        default: self = .blue
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("blue")
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
        return formatter.string(fromDistance: distance)
    }
    
    var formattedTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: expectedTravelTime) ?? ""
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
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func startUpdatingLocation() {
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
                    instructions: route.steps.map { $0.instructions },
                    polyline: route.polyline
                )
            }
        }
    }
}
```