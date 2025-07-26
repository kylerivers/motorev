import Foundation
import CoreLocation
import MapKit
import UserNotifications

class HazardDetectionManager: ObservableObject {
    static let shared = HazardDetectionManager()
    
    // MARK: - Published Properties
    @Published var activeHazards: [Hazard] = []
    @Published var routeAlerts: [RouteAlert] = []
    @Published var weatherAlerts: [WeatherAlert] = []
    @Published var crowdSourcedReports: [CrowdSourcedReport] = []
    @Published var isMonitoring = false
    
    // MARK: - AI Analysis
    private var analysisTimer: Timer?
    private var locationHistory: [CLLocation] = []
    private let maxHistorySize = 100
    
    // MARK: - Hazard Detection Parameters
    private struct HazardThresholds {
        static let sharpTurnRadius: Double = 50.0 // meters
        static let poorRoadSurfaceConfidence: Double = 0.7
        static let weatherVisibilityThreshold: Double = 1000.0 // meters
        static let trafficDensityThreshold: Double = 0.8
        static let speedChangeThreshold: Double = 15.0 // mph difference
    }
    
    private init() {
        loadCrowdSourcedReports()
        setupWeatherMonitoring()
    }
    
    // MARK: - Monitoring Control
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        // Start continuous hazard analysis
        analysisTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.analyzeCurrentConditions()
        }
        
        print("🧠 AI Hazard Detection: MONITORING STARTED")
    }
    
    func stopMonitoring() {
        isMonitoring = false
        analysisTimer?.invalidate()
        analysisTimer = nil
        
        print("🛑 AI Hazard Detection: MONITORING STOPPED")
    }
    
    // MARK: - Core AI Analysis
    private func analyzeCurrentConditions() {
        // In real app, would get location from LocationManager instance via dependency injection
        let defaultLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        // Add to location history
        locationHistory.append(defaultLocation)
        if locationHistory.count > maxHistorySize {
            locationHistory.removeFirst()
        }
        
        // Perform multi-layer analysis
        analyzeRoadConditions(at: defaultLocation)
        analyzeSpeedPatterns()
        analyzeRouteHazards()
        analyzeWeatherImpact(at: defaultLocation)
        analyzeCrowdSourcedData(near: defaultLocation)
        
        // Clean up old alerts
        cleanupExpiredAlerts()
    }
    
    // MARK: - Road Conditions Analysis
    private func analyzeRoadConditions(at location: CLLocation) {
        // AI algorithm to detect poor road surfaces based on movement patterns
        guard locationHistory.count >= 10 else { return }
        
        let recentLocations = Array(locationHistory.suffix(10))
        let speedVariations = calculateSpeedVariations(from: recentLocations)
        let directionChanges = calculateDirectionChanges(from: recentLocations)
        
        // Detect rough road surfaces
        if speedVariations > 5.0 && directionChanges > 3 {
            let confidence = min(speedVariations / 10.0, 0.95)
            
            if confidence > HazardThresholds.poorRoadSurfaceConfidence {
                reportHazard(
                    type: .poorRoadSurface,
                    location: location.coordinate,
                    confidence: confidence,
                    description: "Poor road surface detected based on movement patterns"
                )
            }
        }
        
        // Detect sharp turns ahead
        detectSharpTurns(from: recentLocations)
    }
    
    private func calculateSpeedVariations(from locations: [CLLocation]) -> Double {
        guard locations.count >= 2 else { return 0.0 }
        
        var speedChanges: [Double] = []
        
        for i in 1..<locations.count {
            let speed1 = locations[i-1].speed
            let speed2 = locations[i].speed
            
            if speed1 >= 0 && speed2 >= 0 {
                speedChanges.append(abs(speed2 - speed1))
            }
        }
        
        guard !speedChanges.isEmpty else { return 0.0 }
        return speedChanges.reduce(0, +) / Double(speedChanges.count)
    }
    
    private func calculateDirectionChanges(from locations: [CLLocation]) -> Int {
        guard locations.count >= 3 else { return 0 }
        
        var directionChanges = 0
        
        for i in 2..<locations.count {
            let bearing1 = locations[i-2].coordinate.bearing(to: locations[i-1].coordinate)
            let bearing2 = locations[i-1].coordinate.bearing(to: locations[i].coordinate)
            
            let bearingDifference = abs(bearing1 - bearing2)
            let normalizedDifference = min(bearingDifference, 360 - bearingDifference)
            
            if normalizedDifference > 15.0 { // 15 degree threshold
                directionChanges += 1
            }
        }
        
        return directionChanges
    }
    
    private func detectSharpTurns(from locations: [CLLocation]) {
        guard locations.count >= 3 else { return }
        
        let lastThree = Array(locations.suffix(3))
        
        // Calculate turn radius
        let radius = calculateTurnRadius(
            p1: lastThree[0].coordinate,
            p2: lastThree[1].coordinate,
            p3: lastThree[2].coordinate
        )
        
        if radius < HazardThresholds.sharpTurnRadius {
            let confidence = 1.0 - (radius / HazardThresholds.sharpTurnRadius)
            
            reportHazard(
                type: .sharpTurn,
                location: lastThree[2].coordinate,
                confidence: confidence,
                description: "Sharp turn detected (radius: \(Int(radius))m)"
            )
        }
    }
    
    private func calculateTurnRadius(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D, p3: CLLocationCoordinate2D) -> Double {
        // Simplified radius calculation using three points
        let a = p1.distance(to: p2)
        let b = p2.distance(to: p3)
        let c = p1.distance(to: p3)
        
        // Using Menger curvature formula
        let area = abs((p2.latitude - p1.latitude) * (p3.longitude - p1.longitude) - (p3.latitude - p1.latitude) * (p2.longitude - p1.longitude)) / 2.0
        
        guard area > 0 else { return Double.infinity }
        
        let radius = (a * b * c) / (4.0 * area * 111000) // Convert to meters
        return radius
    }
    
    // MARK: - Speed Pattern Analysis
    private func analyzeSpeedPatterns() {
        guard locationHistory.count >= 5 else { return }
        
        let recentSpeeds = locationHistory.suffix(5).compactMap { location in
            location.speed >= 0 ? location.speed * 2.237 : nil // Convert to mph
        }
        
        guard recentSpeeds.count >= 3 else { return }
        
        // Detect sudden speed changes
        for i in 1..<recentSpeeds.count {
            let speedChange = abs(recentSpeeds[i] - recentSpeeds[i-1])
            
            if speedChange > HazardThresholds.speedChangeThreshold {
                if true { // In real app, would check LocationManager instance
                    let currentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
                    reportHazard(
                        type: .suddenSpeedChange,
                        location: currentLocation.coordinate,
                        confidence: min(speedChange / 30.0, 0.9),
                        description: "Sudden speed change detected: \(Int(speedChange)) mph difference"
                    )
                }
            }
        }
    }
    
    // MARK: - Route Hazards Analysis
    private func analyzeRouteHazards() {
        // In real app, would get current route from LocationManager instance
        // For now, skip route analysis
        return
    }
    
    private func calculateDistanceAhead(routeIndex: Int, route: MKRoute) -> Double {
        // Calculate distance from current position to hazard along route
        // Simplified implementation
        return Double(routeIndex) * 100 // Approximate distance
    }
    
    // MARK: - Weather Impact Analysis
    private func analyzeWeatherImpact(at location: CLLocation) {
        // Simulate weather API call
        fetchWeatherData(for: location) { [weak self] weatherData in
            guard let self = self, let weather = weatherData else { return }
            
            DispatchQueue.main.async {
                self.processWeatherHazards(weather: weather, location: location)
            }
        }
    }
    
    private func processWeatherHazards(weather: WeatherData, location: CLLocation) {
        // Analyze weather conditions for riding hazards
        
        // Low visibility
        if Double(weather.visibility) < HazardThresholds.weatherVisibilityThreshold {
            createWeatherAlert(
                type: WeatherAlertType.lowVisibility,
                location: location.coordinate,
                severity: calculateVisibilitySeverity(Double(weather.visibility)),
                description: "Low visibility: \(weather.visibility)m"
            )
        }
        
        // Precipitation
        if weather.precipitation > 0.1 {
            createWeatherAlert(
                type: WeatherAlertType.precipitation,
                location: location.coordinate,
                severity: calculatePrecipitationSeverity(weather.precipitation),
                description: "Rain detected: \(weather.precipitation)mm/hr"
            )
        }
        
        // Strong winds
        if weather.windSpeed > 15.0 { // 15 mph
            createWeatherAlert(
                type: WeatherAlertType.strongWinds,
                location: location.coordinate,
                severity: calculateWindSeverity(weather.windSpeed),
                description: "Strong winds: \(Int(weather.windSpeed)) mph"
            )
        }
        
        // Temperature extremes
        if weather.temperature < 35 || weather.temperature > 100 {
            createWeatherAlert(
                type: WeatherAlertType.temperatureExtreme,
                location: location.coordinate,
                severity: AlertSeverity.moderate,
                description: "Extreme temperature: \(Int(weather.temperature))°F"
            )
        }
    }
    
    private func calculateVisibilitySeverity(_ visibility: Double) -> AlertSeverity {
        if visibility < 200 { return .critical }
        if visibility < 500 { return .high }
        if visibility < 1000 { return .moderate }
        return .low
    }
    
    private func calculatePrecipitationSeverity(_ precipitation: Double) -> AlertSeverity {
        if precipitation > 10 { return .critical }
        if precipitation > 5 { return .high }
        if precipitation > 1 { return .moderate }
        return .low
    }
    
    private func calculateWindSeverity(_ windSpeed: Double) -> AlertSeverity {
        if windSpeed > 30 { return .critical }
        if windSpeed > 25 { return .high }
        if windSpeed > 20 { return .moderate }
        return .low
    }
    
    // MARK: - Crowd-Sourced Data Analysis
    private func analyzeCrowdSourcedData(near location: CLLocation) {
        let nearbyReports = crowdSourcedReports.filter { report in
            let distance = location.coordinate.distance(to: report.location)
            return distance < 1000 && !report.isExpired // Within 1km and not expired
        }
        
        for report in nearbyReports {
            // Convert crowd-sourced reports to hazards if confidence is high enough
            if report.confidence > 0.6 && !activeHazards.contains(where: { $0.id == report.id }) {
                let hazard = Hazard(
                    id: report.id,
                    type: HazardType.fromReportType(report.type),
                    location: report.location,
                    confidence: report.confidence,
                    description: report.description,
                    timestamp: report.timestamp,
                    severity: AlertSeverity.fromConfidence(report.confidence),
                    source: .crowdSourced
                )
                
                activeHazards.append(hazard)
                notifyHazardDetected(hazard)
            }
        }
    }
    
    // MARK: - Hazard Reporting
    private func reportHazard(type: HazardType, location: CLLocationCoordinate2D, confidence: Double, description: String) {
        // Prevent duplicate hazards in same area
        let isDuplicate = activeHazards.contains { hazard in
            let distance = location.distance(to: hazard.location)
            return distance < 100 && hazard.type == type
        }
        
        guard !isDuplicate else { return }
        
        let hazard = Hazard(
            id: UUID(),
            type: type,
            location: location,
            confidence: confidence,
            description: description,
            timestamp: Date(),
            severity: AlertSeverity.fromConfidence(confidence),
            source: .aiDetected
        )
        
        activeHazards.append(hazard)
        notifyHazardDetected(hazard)
        
        print("⚠️ Hazard detected: \(type.description) at \(location) (confidence: \(Int(confidence * 100))%)")
    }
    
    func reportUserHazard(type: CrowdSourcedReportType, location: CLLocationCoordinate2D, description: String) {
        let report = CrowdSourcedReport(
            id: UUID(),
            type: type,
            location: location,
            description: description,
            reportedBy: SocialManager.shared.currentUser?.username ?? "Anonymous",
            timestamp: Date(),
            confidence: 0.8, // User reports start with high confidence
            votes: 1
        )
        
        crowdSourcedReports.append(report)
        saveCrowdSourcedReports()
        
        print("📝 User reported hazard: \(type.description) at \(location)")
    }
    
    private func createRouteAlert(type: RouteAlertType, location: CLLocationCoordinate2D, hazard: Hazard, distanceAhead: Double) {
        let alert = RouteAlert(
            id: UUID(),
            type: type,
            location: location,
            hazard: hazard,
            distanceAhead: distanceAhead,
            timestamp: Date()
        )
        
        routeAlerts.append(alert)
        notifyRouteAlert(alert)
    }
    
    private func createWeatherAlert(type: WeatherAlertType, location: CLLocationCoordinate2D, severity: AlertSeverity, description: String) {
        let alert = WeatherAlert(
            type: type,
            location: location,
            severity: severity,
            description: description
        )
        
        weatherAlerts.append(alert)
        notifyWeatherAlert(alert)
    }
    
    // MARK: - Notifications
    private func notifyHazardDetected(_ hazard: Hazard) {
        let content = UNMutableNotificationContent()
        content.title = "🚨 Hazard Detected"
        content.body = hazard.description
        content.sound = .default
        content.categoryIdentifier = "HAZARD_ALERT"
        
        let request = UNNotificationRequest(
            identifier: "hazard_\(hazard.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func notifyRouteAlert(_ alert: RouteAlert) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Route Alert"
        content.body = "\(alert.hazard.description) in \(Int(alert.distanceAhead))m"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "route_alert_\(alert.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func notifyWeatherAlert(_ alert: WeatherAlert) {
        guard alert.severity.rawValue >= AlertSeverity.moderate.rawValue else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🌧️ Weather Alert"
        content.body = alert.description
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "weather_alert_\(alert.id)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Data Management
    private func cleanupExpiredAlerts() {
        let cutoffTime = Date().addingTimeInterval(-3600) // 1 hour ago
        
        activeHazards.removeAll { $0.timestamp < cutoffTime }
        routeAlerts.removeAll { $0.timestamp < cutoffTime }
        weatherAlerts.removeAll { $0.timestamp < cutoffTime }
        crowdSourcedReports.removeAll { $0.isExpired }
    }
    
    private func saveCrowdSourcedReports() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(crowdSourcedReports)
            UserDefaults.standard.set(data, forKey: "crowdSourcedReports")
        } catch {
            print("❌ Failed to save crowd-sourced reports: \(error)")
        }
    }
    
    private func loadCrowdSourcedReports() {
        guard let data = UserDefaults.standard.data(forKey: "crowdSourcedReports") else { return }
        
        do {
                            let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                crowdSourcedReports = try decoder.decode([CrowdSourcedReport].self, from: data)
        } catch {
            print("❌ Failed to load crowd-sourced reports: \(error)")
        }
    }
    
    // MARK: - Weather Data
    private func setupWeatherMonitoring() {
        // Setup weather monitoring (would integrate with weather API)
        print("🌤️ Weather monitoring initialized")
    }
    
    // MARK: - Public Weather Methods
    func getWeatherData(for location: CLLocation, completion: @escaping (WeatherData?) -> Void) {
        // Use the real WeatherManager instead of mock data
        WeatherManager.shared.fetchWeatherData(for: location.coordinate)
        
        // Return the current weather from WeatherManager
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(WeatherManager.shared.currentWeather)
        }
    }
    
    private func fetchWeatherData(for location: CLLocation, completion: @escaping (WeatherData?) -> Void) {
        // Deprecated - use WeatherManager directly
        getWeatherData(for: location, completion: completion)
    }
}

// MARK: - Supporting Models
struct Hazard: Identifiable, Codable {
    let id: UUID
    let type: HazardType
    let location: CLLocationCoordinate2D
    let confidence: Double
    let description: String
    let timestamp: Date
    let severity: AlertSeverity
    let source: HazardSource
}

enum HazardType: String, CaseIterable, Codable {
    case poorRoadSurface = "poor_road_surface"
    case sharpTurn = "sharp_turn"
    case suddenSpeedChange = "sudden_speed_change"
    case construction = "construction"
    case debris = "debris"
    case pothole = "pothole"
    case wetRoad = "wet_road"
    case iceRoad = "ice_road"
    
    var description: String {
        switch self {
        case .poorRoadSurface: return "Poor Road Surface"
        case .sharpTurn: return "Sharp Turn"
        case .suddenSpeedChange: return "Speed Zone Change"
        case .construction: return "Construction"
        case .debris: return "Road Debris"
        case .pothole: return "Pothole"
        case .wetRoad: return "Wet Road"
        case .iceRoad: return "Icy Road"
        }
    }
    
    var icon: String {
        switch self {
        case .poorRoadSurface: return "road.lanes"
        case .sharpTurn: return "arrow.turn.up.right"
        case .suddenSpeedChange: return "speedometer"
        case .construction: return "hammer"
        case .debris: return "exclamationmark.triangle"
        case .pothole: return "circle.dotted"
        case .wetRoad: return "cloud.rain"
        case .iceRoad: return "snowflake"
        }
    }
    
    static func fromReportType(_ reportType: CrowdSourcedReportType) -> HazardType {
        switch reportType {
        case .pothole: return .pothole
        case .debris: return .debris
        case .construction: return .construction
        case .poorSurface: return .poorRoadSurface
        case .other: return .poorRoadSurface
        }
    }
}

enum HazardSource: String, Codable {
    case aiDetected = "ai_detected"
    case crowdSourced = "crowd_sourced"
    case official = "official"
}



struct RouteAlert: Identifiable {
    let id: UUID
    let type: RouteAlertType
    let location: CLLocationCoordinate2D
    let hazard: Hazard
    let distanceAhead: Double
    let timestamp: Date
}

enum RouteAlertType: String, CaseIterable {
    case hazardOnRoute = "hazard_on_route"
    case alternativeRoute = "alternative_route"
    case slowDown = "slow_down"
}

struct CrowdSourcedReport: Identifiable, Codable {
    let id: UUID
    let type: CrowdSourcedReportType
    let location: CLLocationCoordinate2D
    let description: String
    let reportedBy: String
    let timestamp: Date
    var confidence: Double
    var votes: Int
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 86400 // 24 hours
    }
}

enum CrowdSourcedReportType: String, CaseIterable, Codable {
    case pothole = "pothole"
    case debris = "debris"
    case construction = "construction"
    case poorSurface = "poor_surface"
    case other = "other"
    
    var description: String {
        switch self {
        case .pothole: return "Pothole"
        case .debris: return "Debris"
        case .construction: return "Construction"
        case .poorSurface: return "Poor Surface"
        case .other: return "Other Hazard"
        }
    }
}

// MARK: - Extensions
extension CLLocationCoordinate2D {
    func distance(to coordinate: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location1.distance(from: location2)
    }
    
    func bearing(to coordinate: CLLocationCoordinate2D) -> Double {
        let lat1 = self.latitude * .pi / 180
        let lat2 = coordinate.latitude * .pi / 180
        let deltaLon = (coordinate.longitude - self.longitude) * .pi / 180
        
        let x = sin(deltaLon) * cos(lat2)
        let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        let bearing = atan2(x, y) * 180 / .pi
        return bearing < 0 ? bearing + 360 : bearing
    }
}

extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
} 