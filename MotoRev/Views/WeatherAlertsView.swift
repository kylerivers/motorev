import SwiftUI
import CoreLocation
import MapKit

extension Array {
    func uniqued<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return self.filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}

struct WeatherAlertsView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var weatherManager: WeatherManager
    @EnvironmentObject var socialManager: SocialManager
    @ObservedObject var hazardDetectionManager = HazardDetectionManager.shared
    @State private var isLoading = true
    @State private var locationName = "Current Location"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Current Location Display
                    if let location = locationManager.location {
                        VStack(spacing: 4) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.green)
                                Text(locationName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Spacer()
                                Button(action: refreshWeatherData) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Text("Lat: \(String(format: "%.4f", location.coordinate.latitude)), Lng: \(String(format: "%.4f", location.coordinate.longitude))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text("Last updated: \(Date(), formatter: timeFormatter)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    // Current Weather Status
                    if let weather = weatherManager.currentWeather {
                        WeatherStatusCard(weather: weather)
                    } else if isLoading {
                        ProgressView("Loading weather data...")
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "location.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            Text("Location Required")
                                .font(.headline)
                                .foregroundColor(.orange)
                            Text("Please enable location services to get weather data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                    
                    // Active Weather Alerts  
                    let uniqueAlerts = weatherManager.weatherAlerts.uniqued(by: \.id)
                    if !uniqueAlerts.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Active Weather Alerts")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Spacer()
                                Text("\(uniqueAlerts.count) alert\(uniqueAlerts.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            ForEach(uniqueAlerts, id: \.id) { alert in
                                WeatherAlertCard(
                                    alert: alert,
                                    onShare: { shareAlert(alert) }
                                )
                            }
                        }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.green)
                            Text("No Active Alerts")
                                .font(.headline)
                                .foregroundColor(.green)
                            Text("Weather conditions are safe for riding")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Weather Radar/Map Integration
                    WeatherMapView()
                        .frame(height: 300)
                        .cornerRadius(10)
                    
                    // Ride Recommendations
                    WeatherRideRecommendations(weather: weatherManager.currentWeather, alerts: weatherManager.weatherAlerts)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Weather Alerts")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            loadWeatherData()
        }
    }
    
    private func loadWeatherData() {
        isLoading = true
        
        guard let location = locationManager.location else {
            isLoading = false
            return
        }
        
        // WeatherManager automatically fetches weather based on location
        weatherManager.fetchWeatherData(for: location.coordinate)
        
        // Get location name
        getLocationName(for: location.coordinate)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
        }
    }
    
    private func refreshWeatherData() {
        guard let location = locationManager.location else { return }
        
        // Clear existing alerts to prevent duplicates
        weatherManager.clearAllAlerts()
        
        // Fetch fresh data
        weatherManager.fetchWeatherData(for: location.coordinate)
        getLocationName(for: location.coordinate)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func getLocationName(for coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    if let city = placemark.locality, let state = placemark.administrativeArea {
                        self.locationName = "\(city), \(state)"
                    } else if let name = placemark.name {
                        self.locationName = name
                    }
                }
            }
        }
    }
    
    private func shareAlert(_ alert: WeatherAlert) {
        let alertTitle = alertTitle(for: alert.type)
        let severityText = severityString(for: alert.severity)
        
        let postContent = """
        🌦️ Weather Alert: \(alertTitle)
        
        📍 Location: \(locationName)
        ⚠️ Severity: \(severityText)
        
        \(alert.description)
        
        #WeatherAlert #MotoRev #RideSafe
        """
        
        // Create a post using SocialManager
        print("Sharing weather alert: \(postContent)")
        // TODO: Implement actual social post creation when SocialManager method is available
        
        // Show success feedback for now
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    private func alertTitle(for type: WeatherAlertType) -> String {
        switch type {
        case .rain, .precipitation:
            return "Rain Alert"
        case .wind, .strongWinds:
            return "Wind Alert"
        case .temperature, .temperatureExtreme:
            return "Temperature Alert"
        case .visibility, .lowVisibility:
            return "Visibility Alert"
        case .severe:
            return "Severe Weather Alert"
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }
    
    private func severityString(for severity: AlertSeverity) -> String {
        switch severity {
        case .low:
            return "Low"
        case .medium, .moderate:
            return "Medium"
        case .high, .severe:
            return "High"
        case .critical:
            return "Critical"
        }
    }
}

struct WeatherStatusCard: View {
    let weather: WeatherData
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading) {
                    Text("\(Int(weather.temperature))°F")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(weather.conditions)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: weatherIcon(for: weather.conditions))
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            }
            
            HStack {
                WeatherDetailItem(title: "Wind", value: "\(Int(weather.windSpeed)) mph")
                Spacer()
                WeatherDetailItem(title: "Humidity", value: "\(Int(weather.humidity))%")
                Spacer()
                WeatherDetailItem(title: "Visibility", value: "\(weather.visibility/1000) mi")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func weatherIcon(for conditions: String) -> String {
        switch conditions.lowercased() {
        case let x where x.contains("rain"):
            return "cloud.rain.fill"
        case let x where x.contains("snow"):
            return "cloud.snow.fill"
        case let x where x.contains("cloud"):
            return "cloud.fill"
        case let x where x.contains("clear"):
            return "sun.max.fill"
        default:
            return "cloud.sun.fill"
        }
    }
}

struct WeatherDetailItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}

struct WeatherAlertCard: View {
    let alert: WeatherAlert
    let onShare: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: alertIcon(for: alert.type))
                    .font(.title2)
                    .foregroundColor(alertColor(for: alert.severity))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(alertTitle(for: alert.type))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(alert.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text("Active since: \(alert.timestamp, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(alertColor(for: alert.severity).opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(alertColor(for: alert.severity), lineWidth: 1)
        )
    }
    
    private func alertTitle(for type: WeatherAlertType) -> String {
        switch type {
        case .rain, .precipitation:
            return "Rain Alert"
        case .wind, .strongWinds:
            return "Wind Alert"
        case .temperature, .temperatureExtreme:
            return "Temperature Alert"
        case .visibility, .lowVisibility:
            return "Visibility Alert"
        case .severe:
            return "Severe Weather Alert"
        }
    }
    
    private func alertIcon(for type: WeatherAlertType) -> String {
        switch type {
        case .rain, .precipitation:
            return "cloud.rain.fill"
        case .wind, .strongWinds:
            return "wind"
        case .temperature, .temperatureExtreme:
            return "thermometer"
        case .visibility, .lowVisibility:
            return "cloud.fog.fill"
        case .severe:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private func alertColor(for severity: AlertSeverity) -> Color {
        switch severity {
        case .low:
            return .yellow
        case .medium, .moderate:
            return .orange
        case .high, .severe:
            return .red
        case .critical:
            return .purple
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }
}

struct WeatherMapView: View {
    @EnvironmentObject var locationManager: LocationManager
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
    )
    
    var body: some View {
        Map(position: .constant(.region(region)))
            .overlay(
                VStack {
                    HStack {
                        Text("Weather Radar")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)
            )
            .onAppear {
                updateRegionToCurrentLocation()
            }
            .onChange(of: locationManager.location) { oldLocation, newLocation in
                updateRegionToCurrentLocation()
            }
    }
    
    private func updateRegionToCurrentLocation() {
        if let location = locationManager.location {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            )
        }
    }
}

struct WeatherRideRecommendations: View {
    let weather: WeatherData?
    let alerts: [WeatherAlert]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ride Recommendations")
                .font(.headline)
                .fontWeight(.bold)
            
            if let weather = weather {
                let ambientF = weather.temperature
                let mph = LocationManager.shared.currentRideSpeed
                let feels = WeatherManager.shared.computeWindChillF(ambientF: ambientF, mph: mph)
                
                VStack(spacing: 8) {
                    RecommendationItem(
                        icon: "thermometer",
                        title: "Ambient vs Feels Like",
                        recommendation: String(format: "%.0f°F feels like %.0f°F at %.0f mph", ambientF, feels, mph)
                    )
                    if PremiumManager.shared.isPremium {
                        let gear = WeatherManager.shared.gearSuggestion(ambientF: ambientF, mph: mph)
                        RecommendationItem(
                            icon: "tshirt",
                            title: "Gear",
                            recommendation: gear
                        )
                    } else {
                        NavigationLink(destination: PaywallView()) {
                            HStack { Image(systemName: "star.fill"); Text("Unlock Gear Recommendations") }
                        }
                    }
                    
                    if !alerts.isEmpty {
                        RecommendationItem(
                            icon: "exclamationmark.triangle.fill",
                            title: "Weather Alerts",
                            recommendation: "Consider postponing ride due to active weather alerts"
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func temperatureRecommendation(_ temp: Double) -> String {
        switch temp {
        case ..<32:
            return "Very cold - ice risk. Full winter gear recommended."
        case 32..<50:
            return "Cold conditions - heated grips and layers recommended."
        case 50..<75:
            return "Good riding temperature - standard gear sufficient."
        case 75..<90:
            return "Warm conditions - ensure proper ventilation."
        default:
            return "Very hot - stay hydrated and take frequent breaks."
        }
    }
    
    private func windRecommendation(_ windSpeed: Double) -> String {
        switch windSpeed {
        case 0..<10:
            return "Calm conditions - ideal for riding."
        case 10..<20:
            return "Light winds - good riding conditions."
        case 20..<30:
            return "Moderate winds - use caution on open roads."
        case 30..<40:
            return "Strong winds - experienced riders only."
        default:
            return "Dangerous wind conditions - avoid riding."
        }
    }
}

struct RecommendationItem: View {
    let icon: String
    let title: String
    let recommendation: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(recommendation)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    WeatherAlertsView()
} 