import Foundation
import CoreLocation
import MapKit
import Combine

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var region: MKCoordinateRegion = MKCoordinateRegion()
    @Published var isTracking = false
    @Published var currentRoute: MKRoute?
    @Published var selectedDestination: String = ""
    @Published var selectedDestinationCoordinate: CLLocationCoordinate2D?
    @Published var rideHistory: [Ride] = []
    @Published var nearbyRiders: [NearbyRider] = []
    
    // Enhanced ride tracking properties
    @Published var rideStartTime: Date?
    @Published var ridePauseTime: Date?
    @Published var isRidePaused = false
    @Published var currentRideDistance: CLLocationDistance = 0.0
    @Published var currentRideSpeed: Double = 0.0 // mph
    @Published var currentRideMaxSpeed: Double = 0.0 // mph
    @Published var currentRideAverageSpeed: Double = 0.0 // mph
    @Published var currentRideDuration: TimeInterval = 0.0 // seconds
    @Published var activePausedDuration: TimeInterval = 0.0 // total paused time
    
    private var rideDistance: CLLocationDistance = 0
    private var lastLocation: CLLocation?
    private var rideTimer: Timer?
    private var pausedDurations: [TimeInterval] = []
    private var currentActiveRideId: Int?
    
    private let locationManager = CLLocationManager()
    
    // Route tracking
    @Published var routePoints: [CLLocation] = []
    @Published var averageSpeed: Double = 0
    @Published var maxSpeed: Double = 0
    @Published var currentSpeed: Double = 0
    
    // Navigation and waypoints
    @Published var routeWaypoints: [RouteWaypoint] = []
    @Published var currentWaypointIndex: Int = 0
    @Published var isNavigating = false
    @Published var navigationInstructions: [NavigationInstruction] = []
    @Published var alternativeRoutes: [MKRoute] = []
    @Published var selectedRouteType: RouteType = .fastest
    @Published var routePreferences = RoutePreferences()
    @Published var offlineMapRegions: [MKCoordinateRegion] = []
    @Published var isOfflineModeEnabled = false
    @Published var offlineMapDownloadProgress: Double = 0.0
    
    private override init() {
        super.init()
        setupLocationManager()
        loadRideHistory()
        loadOfflineMapRegions()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Only enable background updates if we have proper authorization
        // This will be enabled later when we have the proper permissions
        
        // Don't set a default region - let it be determined by actual location
        // The region will be updated when we get the user's first location
    }
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // Handle denied permission
            break
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            startLocationUpdates()
        @unknown default:
            break
        }
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            return
        }
        
        // Enable background location updates only if we have "Always" permission
        // and the app is properly configured for background location
        if authorizationStatus == .authorizedAlways {
            // Check if the app has the background location capability
            if Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] != nil {
                locationManager.allowsBackgroundLocationUpdates = true
                print("✅ Background location updates enabled")
            } else {
                print("⚠️ Background location not available - missing UIBackgroundModes capability")
            }
        }
        
        locationManager.startUpdatingLocation()
        isTracking = true
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        
        // Disable background location updates when stopping
        if authorizationStatus == .authorizedAlways {
            locationManager.allowsBackgroundLocationUpdates = false
        }
        
        isTracking = false
    }
    
    func startRideTracking() {
        print("🏍️ Starting ride tracking...")
        
        // Reset all ride data
        rideStartTime = Date()
        ridePauseTime = nil
        isRidePaused = false
        currentRideDistance = 0.0
        rideDistance = 0
        currentRideSpeed = 0.0
        currentRideMaxSpeed = 0.0
        currentRideAverageSpeed = 0.0
        currentRideDuration = 0.0
        activePausedDuration = 0.0
        pausedDurations.removeAll()
        routePoints.removeAll()
        maxSpeed = 0
        averageSpeed = 0
        lastLocation = nil
        
        // Start location updates
        startLocationUpdates()
        
        // Pre-ride weather check
        if let coord = location?.coordinate {
            WeatherManager.shared.fetchWeatherData(for: coord)
        }
        
        // Start ride timer for duration tracking
        startRideTimer()
        
        // Create ride in backend
        createRideInBackend()
    }
    
    func pauseRideTracking() {
        guard rideStartTime != nil, !isRidePaused else { return }
        
        print("⏸️ Pausing ride tracking...")
        ridePauseTime = Date()
        isRidePaused = true
        
        // Stop the timer
        rideTimer?.invalidate()
        rideTimer = nil
        
        // Pause location updates to save battery
        stopLocationUpdates()
    }
    
    func resumeRideTracking() {
        guard rideStartTime != nil, isRidePaused, let pauseTime = ridePauseTime else { return }
        
        print("▶️ Resuming ride tracking...")
        
        // Add pause duration to total
        let pausedDuration = Date().timeIntervalSince(pauseTime)
        pausedDurations.append(pausedDuration)
        activePausedDuration += pausedDuration
        
        // Reset pause state
        ridePauseTime = nil
        isRidePaused = false
        
        // Restart tracking
        startLocationUpdates()
        startRideTimer()
    }
    
    func stopRideTracking() {
        guard let startTime = rideStartTime else { return }
        
        print("🛑 Stopping ride tracking...")
        
        // Stop timer
        rideTimer?.invalidate()
        rideTimer = nil
        
        // If currently paused, add final pause duration
        if isRidePaused, let pauseTime = ridePauseTime {
            let finalPauseDuration = Date().timeIntervalSince(pauseTime)
            pausedDurations.append(finalPauseDuration)
            activePausedDuration += finalPauseDuration
        }
        
        let endTime = Date()
        let totalDuration = endTime.timeIntervalSince(startTime) - activePausedDuration
        
        // Save ride to backend
        saveRideToBackend(startTime: startTime, endTime: endTime, totalDuration: totalDuration)
        
        // Reset all tracking data
        resetRideData()
    }
    
    private func createRideInBackend() {
        guard let currentLocation = location else { return }
        let startLocation = "\(currentLocation.coordinate.latitude),\(currentLocation.coordinate.longitude)"
        var request = URLRequest(url: URL(string: "\(networkManager.baseURL)/rides/start")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = networkManager.authToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let body: [String: Any?] = ["title": "Solo Ride", "startLocation": startLocation]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ride = json["ride"] as? [String: Any],
               let rideId = ride["id"] as? Int {
                DispatchQueue.main.async { self?.currentActiveRideId = rideId }
            } else {
                print("❌ Failed to create ride: \(error?.localizedDescription ?? "Unknown error")")
            }
        }.resume()
    }
    
    private func saveRideToBackend(startTime: Date, endTime: Date, totalDuration: TimeInterval) {
        guard let rideId = currentActiveRideId else { print("❌ No active ride ID to save"); return }
        let distanceInMiles = currentRideDistance * 0.000621371
        let durationInMinutes = Int(totalDuration / 60)
        let endLoc = routePoints.last.map { "\($0.coordinate.latitude),\($0.coordinate.longitude)" }
        _ = networkManager.endRide(rideId: rideId, endLocation: endLoc, totalDistance: distanceInMiles, maxSpeed: currentRideMaxSpeed, avgSpeed: currentRideAverageSpeed, durationMinutes: durationInMinutes)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] _ in
                print("✅ Ride saved successfully")
                self?.loadRideHistory()
            })
    }
    
    private func startRideTimer() {
        rideTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateRideDuration()
        }
    }
    
    private func updateRideDuration() {
        guard let startTime = rideStartTime, !isRidePaused else { return }
        
        let totalElapsed = Date().timeIntervalSince(startTime)
        currentRideDuration = totalElapsed - activePausedDuration
        
        // Update average speed
        if currentRideDuration > 0 {
            let distanceInMiles = currentRideDistance * 0.000621371
            currentRideAverageSpeed = distanceInMiles / (currentRideDuration / 3600.0)
        }
    }
    
    // Deprecated: use pauseRideTracking()/resumeRideTracking() wrappers below
    // Keeping stubs to avoid breaking callers; forward to tracking methods
    func pauseRide() { pauseRideTracking() }
    func resumeRide() { resumeRideTracking() }
    
    private func resetRideData() {
        rideStartTime = nil
        ridePauseTime = nil
        isRidePaused = false
        currentRideDistance = 0.0
        rideDistance = 0
        currentRideSpeed = 0.0
        currentRideMaxSpeed = 0.0
        currentRideAverageSpeed = 0.0
        currentRideDuration = 0.0
        activePausedDuration = 0.0
        pausedDurations.removeAll()
        routePoints.removeAll()
        maxSpeed = 0
        averageSpeed = 0
        currentActiveRideId = nil
        lastLocation = nil
    }
    
    // Helper function to convert coordinate to string
    private func coordinateToString(_ coordinate: CLLocationCoordinate2D?) -> String {
        guard let coord = coordinate else { return "Unknown" }
        return "\(coord.latitude),\(coord.longitude)"
    }
    
    private func loadRideHistory() {
        networkManager.getRideHistory()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to load ride history: \(error)")
                    }
                },
                receiveValue: { [weak self] (ridesResponse: RidesResponse) in
                    // Extract rides array from response
                    self?.rideHistory = ridesResponse.rides
                    print("✅ Loaded \(ridesResponse.rides.count) rides from API")
                }
            )
            .store(in: &cancellables)
    }
    
    func findNearbyRiders() {
        guard let currentLocation = location else { return }
        
        // Find nearby riders via API
        networkManager.getNearbyRiders(
            latitude: currentLocation.coordinate.latitude,
            longitude: currentLocation.coordinate.longitude,
            radius: 10000 // 10km radius
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ Failed to find nearby riders: \(error)")
                }
            },
            receiveValue: { [weak self] (riders: [NearbyRider]) in
                self?.nearbyRiders = riders
                print("✅ Found \(riders.count) nearby riders")
            }
        )
        .store(in: &cancellables)
    }
    
    func calculateRoute(to destination: CLLocationCoordinate2D, routeType: RouteType = .fastest) {
        guard location != nil else { return }
        
        selectedDestinationCoordinate = destination
        
        switch routeType {
        case .fastest:
            calculateFastestRoute(to: destination)
        case .scenic:
            calculateScenicRoute(to: destination)
        case .highway:
            calculateHighwayRoute(to: destination)
        case .backroads:
            calculateBackroadsRoute(to: destination)
        }
    }
    
    private func calculateFastestRoute(to destination: CLLocationCoordinate2D) {
        guard let currentLocation = location else { return }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: currentLocation.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        request.requestsAlternateRoutes = true
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self = self, let routes = response?.routes, !routes.isEmpty else { return }
            
            DispatchQueue.main.async {
                self.currentRoute = routes.first
                self.alternativeRoutes = Array(routes.dropFirst())
                self.selectedRouteType = .fastest
            }
        }
    }
    
    private func calculateScenicRoute(to destination: CLLocationCoordinate2D) {
        guard let currentLocation = location else { return }
        
        // For scenic routes, try to avoid highways and find alternative routes
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: currentLocation.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        request.requestsAlternateRoutes = true
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self = self, let routes = response?.routes else { return }
            
            // Select the route that avoids highways if available
            let scenicRoute = routes.first { route in
                // Prefer routes without major highways
                return !route.name.localizedCaseInsensitiveContains("interstate") &&
                       !route.name.localizedCaseInsensitiveContains("highway") &&
                       !route.name.localizedCaseInsensitiveContains("freeway")
            } ?? routes.first
            
            DispatchQueue.main.async {
                self.currentRoute = scenicRoute
                self.alternativeRoutes = routes.filter { $0 != scenicRoute }
                self.selectedRouteType = .scenic
            }
        }
    }
    
    private func calculateHighwayRoute(to destination: CLLocationCoordinate2D) {
        guard let currentLocation = location else { return }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: currentLocation.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        request.requestsAlternateRoutes = true
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self = self, let routes = response?.routes else { return }
            
            // Prefer highway routes for faster travel
            let highwayRoute = routes.first { route in
                return route.name.localizedCaseInsensitiveContains("interstate") ||
                       route.name.localizedCaseInsensitiveContains("highway") ||
                       route.name.localizedCaseInsensitiveContains("freeway")
            } ?? routes.first
            
            DispatchQueue.main.async {
                self.currentRoute = highwayRoute
                self.alternativeRoutes = routes.filter { $0 != highwayRoute }
                self.selectedRouteType = .highway
            }
        }
    }
    
    private func calculateBackroadsRoute(to destination: CLLocationCoordinate2D) {
        // Similar to scenic but specifically targeting back roads
        calculateScenicRoute(to: destination)
    }
    
    enum RouteType {
        case fastest
        case scenic
        case highway
        case backroads
    }
    
    struct RoutePreferences {
        var avoidTolls: Bool = false
        var avoidHighways: Bool = false
        var preferScenic: Bool = false
        var maximumDetour: Double = 1.5 // 50% detour allowed
        var fuelStopRadius: Double = 50.0 // Miles
        var restStopInterval: Double = 120.0 // Minutes
    }
    
    func selectAlternativeRoute(_ route: MKRoute) {
        guard alternativeRoutes.contains(route) else { return }
        
        // Swap current route with selected alternative
        if let currentRoute = currentRoute {
            alternativeRoutes.removeAll { $0 == route }
            alternativeRoutes.append(currentRoute)
        }
        
        currentRoute = route
        generateNavigationInstructions(for: route)
    }
    
    func clearDestination() {
        selectedDestination = ""
        selectedDestinationCoordinate = nil
        currentRoute = nil
        alternativeRoutes.removeAll()
        routeWaypoints.removeAll()
        currentWaypointIndex = 0
        isNavigating = false
        navigationInstructions.removeAll()
        selectedRouteType = .fastest
    }
    
    func addWaypoint(_ waypoint: RouteWaypoint) {
        routeWaypoints.append(waypoint)
        
        // Recalculate route with waypoints
        if let destination = selectedDestinationCoordinate {
            calculateRouteWithWaypoints(to: destination)
        }
    }
    
    func removeWaypoint(at index: Int) {
        guard index < routeWaypoints.count else { return }
        routeWaypoints.remove(at: index)
        
        // Recalculate route
        if let destination = selectedDestinationCoordinate {
            calculateRouteWithWaypoints(to: destination)
        }
    }
    
    private func calculateRouteWithWaypoints(to destination: CLLocationCoordinate2D) {
        guard let currentLocation = location else { return }
        
        selectedDestinationCoordinate = destination
        
        // Create waypoint items for route calculation
        var mapItems: [MKMapItem] = [MKMapItem(placemark: MKPlacemark(coordinate: currentLocation.coordinate))]
        
        // Add waypoints
        for waypoint in routeWaypoints {
            let coordinate = CLLocationCoordinate2D(latitude: waypoint.latitude, longitude: waypoint.longitude)
            mapItems.append(MKMapItem(placemark: MKPlacemark(coordinate: coordinate)))
        }
        
        // Add final destination
        mapItems.append(MKMapItem(placemark: MKPlacemark(coordinate: destination)))
        
        calculateMultiWaypointRoute(mapItems: mapItems)
    }
    
    private func calculateMultiWaypointRoute(mapItems: [MKMapItem]) {
        guard mapItems.count >= 2 else { return }
        
        // Calculate route segments between each waypoint
        var routeSegments: [MKRoute] = []
        let group = DispatchGroup()
        
        for i in 0..<(mapItems.count - 1) {
            group.enter()
            
            let request = MKDirections.Request()
            request.source = mapItems[i]
            request.destination = mapItems[i + 1]
            request.transportType = .automobile
            
            let directions = MKDirections(request: request)
            directions.calculate { response, error in
                defer { group.leave() }
                
                if let route = response?.routes.first {
                    routeSegments.append(route)
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self, !routeSegments.isEmpty else { return }
            
            // Use the first segment as primary route for now
            // In production, would combine all segments
            self.currentRoute = routeSegments.first
            self.generateNavigationInstructions(for: routeSegments)
            self.isNavigating = true
        }
    }
    
    private func generateNavigationInstructions(for routes: [MKRoute]) {
        var instructions: [NavigationInstruction] = []
        
        for (index, route) in routes.enumerated() {
            // Add instructions for each route segment
            if index == 0 {
                instructions.append(NavigationInstruction(
                    text: "Start your journey",
                    distance: 0,
                    maneuver: .straight
                ))
            }
            
            // Add turn instruction for waypoints
            if index > 0 {
                let waypointName = routeWaypoints.count > index - 1 ? 
                    routeWaypoints[index - 1].name ?? "waypoint \(index)" : 
                    "waypoint \(index)"
                
                instructions.append(NavigationInstruction(
                    text: "Continue via \(waypointName)",
                    distance: route.distance,
                    maneuver: .straight
                ))
            } else {
                instructions.append(NavigationInstruction(
                    text: "Continue for \(String(format: "%.1f", route.distance * 0.000621371)) miles",
                    distance: route.distance,
                    maneuver: .straight
                ))
            }
        }
        
        instructions.append(NavigationInstruction(
            text: "Arrive at destination",
            distance: 0,
            maneuver: .arrive
        ))
        
        navigationInstructions = instructions
    }
    
    // Overloaded method for single route compatibility
    private func generateNavigationInstructions(for route: MKRoute) {
        generateNavigationInstructions(for: [route])
    }
    
    private func updateSpeed(from location: CLLocation) {
        let speedMph = max(0, location.speed * 2.237) // Convert m/s to mph
        currentSpeed = speedMph
        
        // Update ride-specific speed tracking
        if rideStartTime != nil && !isRidePaused {
            currentRideSpeed = speedMph
            
            if speedMph > currentRideMaxSpeed {
                currentRideMaxSpeed = speedMph
            }
            
            if speedMph > maxSpeed {
                maxSpeed = speedMph
            }
            
            // Update average speed
            updateAverageSpeed()
        }
    }
    
    private func updateAverageSpeed() {
        guard let startTime = rideStartTime, !routePoints.isEmpty else { return }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let distanceInMiles = rideDistance * 0.000621371 // Convert meters to miles
        
        if totalTime > 0 {
            averageSpeed = distanceInMiles / (totalTime / 3600.0) // mph
        }
    }
    
    private func updateRideDistance(from newLocation: CLLocation) {
        guard let lastLoc = lastLocation, rideStartTime != nil, !isRidePaused else { return }
        
        let distance = newLocation.distance(from: lastLoc)
        
        // Only count significant movement to avoid GPS noise
        if distance > 2.0 { // 2 meters minimum
        rideDistance += distance
            currentRideDistance = rideDistance
        }
    }
    

    

    
    func applySharedRoute(_ sharedRoute: SharedRoute) {
        // Clear existing route and waypoints
        clearDestination()
        
        // Convert shared route waypoints to our format
        for waypoint in sharedRoute.waypoints.sorted(by: { $0.order < $1.order }) {
            let routeWaypoint = RouteWaypoint(
                id: waypoint.id,
                latitude: waypoint.latitude,
                longitude: waypoint.longitude,
                name: waypoint.name,
                address: waypoint.address,
                order: waypoint.order,
                waypointType: waypoint.waypointType
            )
            addWaypoint(routeWaypoint)
        }
        
        // Set destination to the last waypoint
        if let lastWaypoint = sharedRoute.waypoints.sorted(by: { $0.order < $1.order }).last {
            let destination = CLLocationCoordinate2D(
                latitude: lastWaypoint.latitude,
                longitude: lastWaypoint.longitude
            )
            selectedDestination = lastWaypoint.name ?? "Shared Destination"
            calculateRoute(to: destination, routeType: .fastest)
        }
    }
    
    // Voice assistant friendly wrappers
    func startRide() { startRideTracking() }
    func stopRide() { stopRideTracking() }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        // Update current location
        location = newLocation
        
        // Update region
        region = MKCoordinateRegion(
            center: newLocation.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        // Update speed
        updateSpeed(from: newLocation)
        
        // Track ride if active
        if rideStartTime != nil {
            routePoints.append(newLocation)
            updateRideDistance(from: newLocation)
        }
        
        // Find nearby riders
        findNearbyRiders()
        
        lastLocation = newLocation
    }
    

    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        switch status {
        case .authorizedAlways:
            print("✅ Location permission: Always authorized")
            startLocationUpdates()
        case .authorizedWhenInUse:
            print("✅ Location permission: When in use authorized")
            startLocationUpdates()
        case .denied:
            print("❌ Location permission: Denied")
            stopLocationUpdates()
        case .restricted:
            print("❌ Location permission: Restricted")
            stopLocationUpdates()
        case .notDetermined:
            print("⚠️ Location permission: Not determined")
            break
        @unknown default:
            print("⚠️ Location permission: Unknown status")
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
    }
}

// MARK: - Offline Maps Extension
extension LocationManager {
    func downloadOfflineMap(for region: MKCoordinateRegion, completion: @escaping (Result<Void, Error>) -> Void) {
        // In a real implementation, this would use MKTileOverlay or a third-party service
        // For now, we'll simulate the download process
        
        let downloadTask = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // Simulate download progress
            for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
                Thread.sleep(forTimeInterval: 0.2)
                DispatchQueue.main.async {
                    self.offlineMapDownloadProgress = progress
                }
            }
            
            DispatchQueue.main.async {
                self.offlineMapRegions.append(region)
                self.saveOfflineMapRegions()
                completion(.success(()))
            }
        }
        
        DispatchQueue.global(qos: .background).async(execute: downloadTask)
    }
    
    func removeOfflineMap(for region: MKCoordinateRegion) {
        offlineMapRegions.removeAll { existingRegion in
            abs(existingRegion.center.latitude - region.center.latitude) < 0.001 &&
            abs(existingRegion.center.longitude - region.center.longitude) < 0.001
        }
        saveOfflineMapRegions()
    }
    
    func toggleOfflineMode() {
        isOfflineModeEnabled.toggle()
        UserDefaults.standard.set(isOfflineModeEnabled, forKey: "isOfflineModeEnabled")
    }
    
    private func saveOfflineMapRegions() {
        let regionData = offlineMapRegions.map { region in
            [
                "latitude": region.center.latitude,
                "longitude": region.center.longitude,
                "latitudeDelta": region.span.latitudeDelta,
                "longitudeDelta": region.span.longitudeDelta
            ]
        }
        UserDefaults.standard.set(regionData, forKey: "offlineMapRegions")
    }
    
    private func loadOfflineMapRegions() {
        isOfflineModeEnabled = UserDefaults.standard.bool(forKey: "isOfflineModeEnabled")
        
        if let regionData = UserDefaults.standard.array(forKey: "offlineMapRegions") as? [[String: Double]] {
            offlineMapRegions = regionData.compactMap { data in
                guard let lat = data["latitude"],
                      let lon = data["longitude"],
                      let latDelta = data["latitudeDelta"],
                      let lonDelta = data["longitudeDelta"] else { return nil }
                
                return MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
                )
            }
        }
    }
    
    func isLocationCoveredByOfflineMap(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return offlineMapRegions.contains { region in
            let minLat = region.center.latitude - region.span.latitudeDelta / 2
            let maxLat = region.center.latitude + region.span.latitudeDelta / 2
            let minLon = region.center.longitude - region.span.longitudeDelta / 2
            let maxLon = region.center.longitude + region.span.longitudeDelta / 2
            
            return coordinate.latitude >= minLat && coordinate.latitude <= maxLat &&
                   coordinate.longitude >= minLon && coordinate.longitude <= maxLon
        }
    }
} 