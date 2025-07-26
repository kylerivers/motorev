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
        
        // Heavy precipitation alert
        if weather.precipitation > 0.2 {
            newAlerts.append(WeatherAlert(
                type: .rain,
                location: coordinate,
                severity: .moderate,
                description: "Heavy precipitation: \(String(format: "%.1f", weather.precipitation)) in/hr"
            ))
        }
                
                DispatchQueue.main.async {
            self.weatherAlerts = newAlerts
            }
    }
    
    private func processWeatherForAlerts(_ weather: WeatherData) {
        guard isWeatherAlertsEnabled else { return }
        
        var newAlerts: [WeatherAlert] = []
        
        // Rain alert
        if weather.precipitation > 0.1 {
            newAlerts.append(WeatherAlert(
                id: "rain-\(Date().timeIntervalSince1970)",
                type: WeatherAlertType.rain,
                severity: weather.precipitation > 0.5 ? AlertSeverity.high : AlertSeverity.medium,
                title: "Rain Detected",
                message: "Current precipitation: \(String(format: "%.1f", weather.precipitation))mm. Ride with caution.",
                location: weather.locationName
            ))
        }
        
        // Wind alert
        if weather.windSpeed > 25 {
            newAlerts.append(WeatherAlert(
                id: "wind-\(Date().timeIntervalSince1970)",
                type: WeatherAlertType.wind,
                severity: weather.windSpeed > 40 ? AlertSeverity.high : AlertSeverity.medium,
                title: "High Winds",
                message: "Wind speed: \(Int(weather.windSpeed)) mph. Strong crosswinds possible.",
                location: weather.locationName
            ))
        }
        
        // Temperature alert
        if weather.temperature < 32 {
            newAlerts.append(WeatherAlert(
                id: "temp-\(Date().timeIntervalSince1970)",
                type: WeatherAlertType.temperature,
                severity: AlertSeverity.medium,
                title: "Freezing Temperature",
                message: "Temperature: \(Int(weather.temperature))°F. Watch for ice on roads.",
                location: weather.locationName
            ))
        }
        
        // Visibility alert
        if weather.visibility < 5000 {
            newAlerts.append(WeatherAlert(
                id: "visibility-\(Date().timeIntervalSince1970)",
                type: WeatherAlertType.visibility,
                severity: weather.visibility < 1000 ? AlertSeverity.high : AlertSeverity.medium,
                title: "Poor Visibility",
                message: "Visibility: \(Int(weather.visibility))m. Fog or heavy precipitation.",
                location: weather.locationName
            ))
        }
        
        // Send notifications for new alerts
        for alert in newAlerts {
            sendWeatherNotification(alert)
        }
        
        weatherAlerts.append(contentsOf: newAlerts)
        
        // Keep only recent alerts (last 24 hours)
        let yesterday = Date().addingTimeInterval(-24 * 60 * 60)
        weatherAlerts.removeAll { $0.timestamp < yesterday }
    }
    
    private func processWeatherAlerts(_ alerts: [OpenWeatherAlert]) {
        for alert in alerts {
            let weatherAlert = WeatherAlert(
                id: "severe-\(alert.start)",
                type: WeatherAlertType.severe,
                severity: AlertSeverity.high,
                title: alert.event,
                message: alert.description,
                location: "Current Location"
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
}