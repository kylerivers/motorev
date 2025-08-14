import Foundation
import CoreLocation
import UserNotifications
import Combine

class WeatherManager: ObservableObject {
    static let shared = WeatherManager()
    
    private let locationManager = LocationManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let notificationCenter = UNUserNotificationCenter.current()
    
    @Published var currentWeather: WeatherData?
    @Published var weatherAlerts: [WeatherAlert] = []
    @Published var isWeatherAlertsEnabled = true
    
    // Using a free weather API service
    private let baseURL = "https://api.open-meteo.com/v1"
    
    private init() {
        setupLocationTracking()
        requestNotificationPermission()
    }
    
    private func setupLocationTracking() {
        locationManager.$location
            .compactMap { $0 }
            .removeDuplicates { location1, location2 in
                // Only update if location changed significantly (>1km)
                location1.distance(from: location2) < 1000
            }
            .sink { [weak self] (location: CLLocation) in
                self?.fetchWeatherData(for: location.coordinate)
                self?.checkForWeatherAlerts(at: location.coordinate)
            }
            .store(in: &cancellables)
    }
    
    private func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Weather notification permission error: \(error)")
            }
        }
    }
    
    func fetchWeatherData(for coordinate: CLLocationCoordinate2D) {
        // Using Open-Meteo free API
        let urlString = "\(baseURL)/forecast?latitude=\(coordinate.latitude)&longitude=\(coordinate.longitude)&current=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m,weather_code&temperature_unit=fahrenheit&wind_speed_unit=mph&timezone=auto"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                print("Weather API error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                let weatherResponse = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                let weatherData = WeatherData(from: weatherResponse, coordinate: coordinate)
                
                DispatchQueue.main.async {
                    self?.currentWeather = weatherData
                    self?.processWeatherForAlerts(weatherData)
                }
            } catch {
                print("Weather decoding error: \(error)")
            }
        }.resume()
    }
    
    private func checkForWeatherAlerts(at coordinate: CLLocationCoordinate2D) {
        // For now, we'll use basic weather conditions to generate alerts
        // A more robust implementation would use a weather alerts API
        guard let weather = currentWeather else { return }
        
        var newAlerts: [WeatherAlert] = []
        
        // High wind alert
        if weather.windSpeed > 25 {
            newAlerts.append(WeatherAlert(
                type: .wind,
                location: coordinate,
                severity: .moderate,
                description: "High winds detected: \(Int(weather.windSpeed)) mph"
            ))
        }
        
        // No additional processing needed here
    }
    
    private func cleanupOldAlerts(currentWeather: WeatherData) {
        weatherAlerts.removeAll { alert in
            switch alert.id {
            case "rain-alert":
                return currentWeather.precipitation <= 0.1
            case "wind-alert":
                return currentWeather.windSpeed <= 25
            case "temperature-alert":
                return currentWeather.temperature >= 32
            case "visibility-alert":
                return currentWeather.visibility >= 5000
            default:
                // Remove alerts older than 1 hour
                return Date().timeIntervalSince(alert.timestamp) > 3600
            }
        }
    }
    
    private func processWeatherForAlerts(_ weather: WeatherData) {
        guard isWeatherAlertsEnabled else { return }
        
        var newAlerts: [WeatherAlert] = []
        
        // Rain alert
        if weather.precipitation > 0.1 {
            let alertId = "rain-alert"
            // Only add if we don't already have this alert
            if !weatherAlerts.contains(where: { $0.id == alertId }) {
                newAlerts.append(WeatherAlert(
                    id: alertId,
                    type: WeatherAlertType.rain,
                    location: locationManager.location?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    severity: weather.precipitation > 0.5 ? AlertSeverity.high : AlertSeverity.medium,
                    description: "Rain Detected: Current precipitation \(String(format: "%.1f", weather.precipitation))mm. Ride with caution."
                ))
            }
        }
        
        // Wind alert
        if weather.windSpeed > 25 {
            let alertId = "wind-alert"
            if !weatherAlerts.contains(where: { $0.id == alertId }) {
                newAlerts.append(WeatherAlert(
                    id: alertId,
                    type: WeatherAlertType.wind,
                    location: locationManager.location?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    severity: weather.windSpeed > 40 ? AlertSeverity.high : AlertSeverity.medium,
                    description: "High Winds: Wind speed \(Int(weather.windSpeed)) mph. Strong crosswinds possible."
                ))
            }
        }
        
        // Temperature alert
        if weather.temperature < 32 {
            let alertId = "temperature-alert"
            if !weatherAlerts.contains(where: { $0.id == alertId }) {
                newAlerts.append(WeatherAlert(
                    id: alertId,
                    type: WeatherAlertType.temperature,
                    location: locationManager.location?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    severity: AlertSeverity.medium,
                    description: "Freezing Temperature: \(Int(weather.temperature))°F. Watch for ice on roads."
                ))
            }
        }
        
        // Visibility alert
        if weather.visibility < 5000 {
            let alertId = "visibility-alert"
            if !weatherAlerts.contains(where: { $0.id == alertId }) {
                newAlerts.append(WeatherAlert(
                    id: alertId,
                    type: WeatherAlertType.visibility,
                    location: locationManager.location?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    severity: weather.visibility < 1000 ? AlertSeverity.high : AlertSeverity.medium,
                    description: "Poor Visibility: \(Int(weather.visibility))m. Fog or heavy precipitation."
                ))
        }
        
        // Send notifications for new alerts
        for alert in newAlerts {
            // TODO: Implement notification sending
            print("Weather alert: \(alert.description)")
        }
        
        weatherAlerts.append(contentsOf: newAlerts)
        
        // Keep only recent alerts (last 24 hours)
        let yesterday = Date().addingTimeInterval(-24 * 60 * 60)
        weatherAlerts.removeAll { $0.timestamp < yesterday }
    }
    
    // End of processWeatherForAlerts function - adding missing closing brace
    }
    
    private func processWeatherAlerts(_ alerts: [OpenWeatherAlert]) {
        for alert in alerts {
            let weatherAlert = WeatherAlert(
                id: "severe-\(alert.start)",
                type: WeatherAlertType.severe,
                location: locationManager.location?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                severity: AlertSeverity.high,
                description: "\(alert.event): \(alert.description)"
            )
            
            sendWeatherNotification(weatherAlert)
            weatherAlerts.append(weatherAlert)
        }
    }
    
    private func sendWeatherNotification(_ alert: WeatherAlert) {
        let content = UNMutableNotificationContent()
        content.title = "🌦️ MotoRev Weather Alert"
        content.subtitle = alert.type.rawValue.capitalized
        content.body = alert.description
        content.sound = .default
        content.badge = 1
        
        // Add custom data
        content.userInfo = [
            "alertType": alert.type.rawValue,
            "severity": alert.severity.rawValue,
            "location": alert.location
        ]
        
        let request = UNNotificationRequest(
            identifier: alert.id,
            content: content,
            trigger: nil // Immediate notification
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Weather notification error: \(error)")
            }
        }
    }
    
    func dismissAlert(_ alertId: String) {
        weatherAlerts.removeAll { $0.id == alertId }
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [alertId])
    }
    
    func toggleWeatherAlerts() {
        isWeatherAlertsEnabled.toggle()
    }
    
    func computeWindChillF(ambientF: Double, mph: Double) -> Double {
        // NWS wind chill formula valid for T<=50F and v>=3 mph
        guard ambientF <= 50, mph >= 3 else { return ambientF }
        let vPow = pow(mph, 0.16)
        return 35.74 + 0.6215*ambientF - 35.75*vPow + 0.4275*ambientF*vPow
    }
    
    func clearAllAlerts() {
        weatherAlerts.removeAll()
    }
    
    func gearSuggestion(ambientF: Double, mph: Double) -> String {
        let feels = computeWindChillF(ambientF: ambientF, mph: mph)
        switch feels {
        case ..<32: return "Full winter gear recommended"
        case 32..<45: return "Gloves and base layer recommended"
        case 45..<60: return "Light layers and windproof jacket"
        case 60..<80: return "Standard gear with ventilation"
        default: return "Hot conditions — hydrate and ventilate"
        }
    }
}