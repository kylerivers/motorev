import Foundation
import WatchConnectivity
import CoreLocation

class WatchManager: NSObject, ObservableObject {
    static let shared = WatchManager()
    @Published var isWatchConnected = false
    @Published var isWatchReachable = false
    @Published var watchBatteryLevel: Float = 0.0
    @Published var watchHeartRate: Int = 0
    @Published var isRideActiveOnWatch = false
    
    private var session: WCSession?
    
    private override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    // MARK: - Watch Connectivity Setup
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
        }
    }
    
    func startSession() {
        session?.activate()
    }
    
    // MARK: - Ride Management
    func startRideOnWatch() {
        guard let session = session, session.isReachable else { return }
        
        let message = [
            "action": "startRide",
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        session.sendMessage(message, replyHandler: { response in
            DispatchQueue.main.async {
                self.isRideActiveOnWatch = true
            }
        }, errorHandler: { error in
            print("Error starting ride on watch: \(error.localizedDescription)")
        })
    }
    
    func stopRideOnWatch() {
        guard let session = session, session.isReachable else { return }
        
        let message = [
            "action": "stopRide",
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        session.sendMessage(message, replyHandler: { response in
            DispatchQueue.main.async {
                self.isRideActiveOnWatch = false
            }
        }, errorHandler: { error in
            print("Error stopping ride on watch: \(error.localizedDescription)")
        })
    }
    
    // MARK: - Emergency Features
    func sendEmergencyAlert() {
        guard let session = session, session.isReachable else { return }
        
        let message = [
            "action": "emergency",
            "type": "crashDetected",
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("Error sending emergency alert to watch: \(error.localizedDescription)")
        })
    }
    
    func sendSafetyStatusUpdate(status: String) {
        guard let session = session else { return }
        
        let context = [
            "safetyStatus": status,
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        do {
            try session.updateApplicationContext(context)
        } catch {
            print("Error updating safety status on watch: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Location and Stats
    func sendLocationUpdate(location: CLLocation, speed: Double) {
        guard let session = session else { return }
        
        let context = [
            "location": [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "speed": speed,
                "timestamp": Date().timeIntervalSince1970
            ]
        ] as [String : Any]
        
        do {
            try session.updateApplicationContext(context)
        } catch {
            print("Error updating location on watch: \(error.localizedDescription)")
        }
    }
    
    func sendRideStats(distance: Double, duration: TimeInterval, averageSpeed: Double) {
        guard let session = session else { return }
        
        let context = [
            "rideStats": [
                "distance": distance,
                "duration": duration,
                "averageSpeed": averageSpeed,
                "timestamp": Date().timeIntervalSince1970
            ]
        ] as [String : Any]
        
        do {
            try session.updateApplicationContext(context)
        } catch {
            print("Error updating ride stats on watch: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Notifications
    func sendNotificationToWatch(title: String, message: String, category: String = "general") {
        guard let session = session, session.isReachable else { return }
        
        let notification = [
            "action": "notification",
            "title": title,
            "message": message,
            "category": category,
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        session.sendMessage(notification, replyHandler: nil, errorHandler: { error in
            print("Error sending notification to watch: \(error.localizedDescription)")
        })
    }
    
    // MARK: - Watch App Controls
    func requestWatchStatus() {
        guard let session = session, session.isReachable else { return }
        
        let message = ["action": "getStatus"] as [String : Any]
        
        session.sendMessage(message, replyHandler: { response in
            DispatchQueue.main.async {
                if let batteryLevel = response["batteryLevel"] as? Float {
                    self.watchBatteryLevel = batteryLevel
                }
                if let heartRate = response["heartRate"] as? Int {
                    self.watchHeartRate = heartRate
                }
                if let isRideActive = response["isRideActive"] as? Bool {
                    self.isRideActiveOnWatch = isRideActive
                }
            }
        }, errorHandler: { error in
            print("Error requesting watch status: \(error.localizedDescription)")
        })
    }
    
    // MARK: - Complication Data
    func updateComplicationData(currentSpeed: Double, distance: Double, safetyStatus: String) {
        guard let session = session else { return }
        
        let complicationData = [
            "complicationData": [
                "speed": currentSpeed,
                "distance": distance,
                "safetyStatus": safetyStatus,
                "timestamp": Date().timeIntervalSince1970
            ]
        ] as [String : Any]
        
        do {
            try session.updateApplicationContext(complicationData)
        } catch {
            print("Error updating complication data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Emergency SOS Integration
    func setupEmergencySOSIntegration() {
        // Integration with Apple Watch Emergency SOS
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(emergencySOSTriggered),
            name: .emergencyTriggered,
            object: nil
        )
    }
    
    @objc private func emergencySOSTriggered() {
        sendEmergencyAlert()
        
        // Trigger watch's emergency features
        guard let session = session, session.isReachable else { return }
        
        let emergencyMessage = [
            "action": "triggerEmergency",
            "type": "crashDetected",
            "location": "auto", // Watch will get location
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        session.sendMessage(emergencyMessage, replyHandler: nil, errorHandler: { error in
            print("Error triggering emergency on watch: \(error.localizedDescription)")
        })
    }
    
    // MARK: - Workout Integration
    func startWorkoutOnWatch() {
        guard let session = session, session.isReachable else { return }
        
        let message = [
            "action": "startWorkout",
            "workoutType": "motorcycleRide",
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("Error starting workout on watch: \(error.localizedDescription)")
        })
    }
    
    func stopWorkoutOnWatch() {
        guard let session = session, session.isReachable else { return }
        
        let message = [
            "action": "stopWorkout",
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("Error stopping workout on watch: \(error.localizedDescription)")
        })
    }
}

// MARK: - WCSessionDelegate
extension WatchManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchConnected = activationState == .activated
            
            if let error = error {
                print("Watch session activation failed: \(error.localizedDescription)")
            } else {
                print("Watch session activated successfully")
                self.requestWatchStatus()
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchConnected = false
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchConnected = false
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.handleWatchMessage(message)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            self.handleWatchMessage(message)
            
            // Send reply if needed
            let reply = ["status": "received"] as [String : Any]
            replyHandler(reply)
        }
    }
    
    private func handleWatchMessage(_ message: [String : Any]) {
        guard let action = message["action"] as? String else { return }
        
        switch action {
        case "heartRateUpdate":
            if let heartRate = message["heartRate"] as? Int {
                self.watchHeartRate = heartRate
            }
            
        case "batteryLevelUpdate":
            if let batteryLevel = message["batteryLevel"] as? Float {
                self.watchBatteryLevel = batteryLevel
            }
            
        case "emergencyButtonPressed":
            // Handle emergency button press from watch
            NotificationCenter.default.post(name: .watchEmergencyPressed, object: nil)
            
        case "rideStarted":
            self.isRideActiveOnWatch = true
            
        case "rideStopped":
            self.isRideActiveOnWatch = false
            
        case "sosTriggered":
            // Handle SOS from watch
            NotificationCenter.default.post(name: .watchSOSTriggered, object: message)
            
        default:
            print("Unknown watch message action: \(action)")
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            // Handle application context updates from watch
            if let watchData = applicationContext["watchData"] as? [String: Any] {
                if let batteryLevel = watchData["batteryLevel"] as? Float {
                    self.watchBatteryLevel = batteryLevel
                }
                if let heartRate = watchData["heartRate"] as? Int {
                    self.watchHeartRate = heartRate
                }
            }
        }
    }
}

// MARK: - Notification Extensions
extension Foundation.Notification.Name {
    static let watchEmergencyPressed = Foundation.Notification.Name("watchEmergencyPressed")
    static let watchSOSTriggered = Foundation.Notification.Name("watchSOSTriggered")
} 