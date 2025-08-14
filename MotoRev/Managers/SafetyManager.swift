import Foundation
import CoreMotion
import CoreLocation
import UserNotifications
import UIKit
import Combine
import AudioToolbox

class SafetyManager: ObservableObject {
    static let shared = SafetyManager()
    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isRiding = false
    @Published var safetyStatus: SafetyStatus = .safe
    @Published var emergencyContacts: [EmergencyContact] = []
    @Published var lastCrashAlert: Date?
    
    // Settings properties
    @Published var autoCallEmergency = false
    @Published var safetyAlertsEnabled = true
    
    private let motionManager = CMMotionManager()
    private let locationManager = CLLocationManager()
    private var crashDetectionTimer: Timer?
    
    // Crash detection thresholds
    private let crashAccelerationThreshold: Double = 4.0 // G-force
    private let crashRotationThreshold: Double = 6.0 // rad/s
    private let crashTimeWindow: TimeInterval = 2.0 // seconds
    
    // Emergency countdown
    @Published var emergencyCountdown: Int = 0
    private var emergencyTimer: Timer?
    
    enum SafetyStatus {
        case safe
        case warning
        case emergency
        case crashDetected
    }
    
    private init() {
        setupMotionManager()
        setupNotifications()
        loadEmergencyContacts()
    }
    
    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 0.1 // 10Hz
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            self.processMotionData(motion)
        }
    }
    
    func startRide() {
        isRiding = true
        safetyStatus = .safe
        startLocationTracking()
        
        // Notify emergency contacts about ride start
        notifyEmergencyContacts(message: "Started motorcycle ride. MotoRev is monitoring for safety.")
    }
    
    func stopRide() {
        isRiding = false
        safetyStatus = .safe
        emergencyCountdown = 0
        emergencyTimer?.invalidate()
        
        // Notify emergency contacts about safe arrival
        notifyEmergencyContacts(message: "Motorcycle ride completed safely.")
    }
    
    private func processMotionData(_ motion: CMDeviceMotion) {
        guard isRiding else { return }
        
        let acceleration = motion.userAcceleration
        let rotation = motion.rotationRate
        
        // Calculate total acceleration magnitude
        let totalAcceleration = sqrt(
            acceleration.x * acceleration.x +
            acceleration.y * acceleration.y +
            acceleration.z * acceleration.z
        )
        
        // Calculate total rotation magnitude
        let totalRotation = sqrt(
            rotation.x * rotation.x +
            rotation.y * rotation.y +
            rotation.z * rotation.z
        )
        
        // Check for crash indicators
        if totalAcceleration > crashAccelerationThreshold || totalRotation > crashRotationThreshold {
            detectPotentialCrash()
        }
        
        // Check for unusual patterns that might indicate danger
        if totalAcceleration > 2.0 || totalRotation > 3.0 {
            if safetyStatus == .safe {
                safetyStatus = .warning
            }
        } else {
            if safetyStatus == .warning {
                safetyStatus = .safe
            }
        }
    }
    
    private func detectPotentialCrash() {
        safetyStatus = .crashDetected
        lastCrashAlert = Date()
        
        // Start emergency countdown
        emergencyCountdown = 30 // 30 seconds to cancel
        startEmergencyCountdown()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Play alert sound
        playEmergencyAlert()
    }
    
    private func startEmergencyCountdown() {
        emergencyTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.emergencyCountdown > 0 {
                self.emergencyCountdown -= 1
                
                // Haptic feedback every 5 seconds
                if self.emergencyCountdown % 5 == 0 {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
            } else {
                self.triggerEmergencyProtocol()
            }
        }
    }
    
    func cancelEmergencyAlert() {
        emergencyTimer?.invalidate()
        emergencyCountdown = 0
        safetyStatus = .safe
    }
    
    private func triggerEmergencyProtocol() {
        safetyStatus = .emergency
        
        // Report emergency to API
        reportEmergencyEvent()
        
        // Send emergency alerts with location
        sendEmergencyAlerts()
        
        // Trigger Apple Watch emergency features
        NotificationCenter.default.post(name: .emergencyTriggered, object: nil)
    }
    
    private func reportEmergencyEvent() {
        guard let location = locationManager.location else { return }
        
        let ice = loadICEPayload()
        let payload = EmergencyReportRequest(
            type: "crash",
            severity: "critical",
            location: EmergencyLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
            description: "Automatic crash detection triggered",
            automaticDetection: true,
            sensorData: nil,
            ice: ice
        )
        networkManager.reportEmergency(payload)
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ Failed to report emergency event: \(error)")
                }
            },
                receiveValue: { (_: EmergencyReportResponse) in
                print("✅ Emergency event reported to API")
            }
        )
        .store(in: &cancellables)
    }
    
    private func sendEmergencyAlerts() {
        guard let location = locationManager.location else { return }
        
        let message = """
        EMERGENCY: Motorcycle crash detected!
        
        Location: \(location.coordinate.latitude), \(location.coordinate.longitude)
        Time: \(Date().formatted())
        
        This is an automated message from MotoRev. Please check on the rider immediately.
        """
        
        // Send to emergency contacts
        for contact in emergencyContacts {
            sendEmergencyMessage(to: contact, message: message)
        }
        
        // Call emergency services (user configurable)
        if UserDefaults.standard.bool(forKey: "autoCallEmergency") {
            callEmergencyServices()
        }
    }
    
    private func sendEmergencyMessage(to contact: EmergencyContact, message: String) {
        // Implementation for SMS/messaging emergency contacts
        print("Emergency message sent to \(contact.name): \(message)")
    }
    
    private func callEmergencyServices() {
        if let phoneURL = URL(string: "tel://911") {
            UIApplication.shared.open(phoneURL)
        }
    }
    
    private func notifyEmergencyContacts(message: String) {
        // Send non-emergency notifications to contacts
        for contact in emergencyContacts {
            print("Notifying \(contact.name): \(message)")
        }
    }
    
    private func startLocationTracking() {
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    private func setupMotionManager() {
        // Configure motion manager for optimal crash detection
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            }
        }
    }
    
    private func loadEmergencyContacts() {
        // First try to load from local storage
        if let data = UserDefaults.standard.data(forKey: "emergencyContacts") {
            do {
                emergencyContacts = try JSONDecoder().decode([EmergencyContact].self, from: data)
                print("✅ Loaded \(emergencyContacts.count) emergency contacts from local storage")
                return
            } catch {
                print("❌ Failed to decode local emergency contacts: \(error)")
            }
        }
        
        // Fallback to API/default contacts
        networkManager.getCurrentUser()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to load user data: \(error)")
                        self.loadDefaultContacts()
                    }
                },
                receiveValue: { [weak self] user in
                    // Extract emergency contacts from user response
                    // For now, just load default contacts since User doesn't have emergency contact fields
                    self?.loadDefaultContacts()
                }
            )
            .store(in: &cancellables)
    }
    
    private func createContactsFromUserData(_ userResponse: UserResponse) {
        // For now, just load default contacts since User model doesn't have emergency contact fields
        // In a production app, emergency contacts would be stored separately
        loadDefaultContacts()
    }
    
    private func loadDefaultContacts() {
        emergencyContacts = [
            EmergencyContact(
                id: UUID(),
                name: "Emergency Contact 1", 
                phoneNumber: "+1234567890", 
                relationship: "Family",
                isPrimary: true
            ),
            EmergencyContact(
                id: UUID(),
                name: "Emergency Contact 2", 
                phoneNumber: "+0987654321", 
                relationship: "Friend",
                isPrimary: false
            )
        ]
        saveEmergencyContacts()
        print("📝 Created default emergency contacts")
    }
    
    func addEmergencyContact(_ contact: EmergencyContact) {
        emergencyContacts.append(contact)
        saveEmergencyContacts()
        print("✅ Added emergency contact: \(contact.name)")
    }
    
    func removeEmergencyContact(_ contact: EmergencyContact) {
        emergencyContacts.removeAll { $0.id == contact.id }
        saveEmergencyContacts()
        print("✅ Removed emergency contact: \(contact.name)")
    }
    
    func updateEmergencyContact(_ contact: EmergencyContact) {
        if let index = emergencyContacts.firstIndex(where: { $0.id == contact.id }) {
            emergencyContacts[index] = contact
            saveEmergencyContacts()
            print("✅ Updated emergency contact: \(contact.name)")
        }
    }
    
    private func saveEmergencyContacts() {
        // Save locally for immediate sync across views
        do {
            let data = try JSONEncoder().encode(emergencyContacts)
            UserDefaults.standard.set(data, forKey: "emergencyContacts")
            print("✅ Emergency contacts saved locally")
        } catch {
            print("❌ Failed to save emergency contacts locally: \(error)")
        }
        
        // Update emergency contact info in user profile via API
        guard let primaryContact = emergencyContacts.first(where: { $0.isPrimary }) ?? emergencyContacts.first else { 
            // If no contacts, clear the API fields
            let updates: [String: Any] = [
                "emergency_contact_name": NSNull(),
                "emergency_contact_phone": NSNull()
            ]
            
            networkManager.updateProfile(updates)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("❌ Failed to clear emergency contacts: \(error)")
                        }
                    },
                    receiveValue: { _ in
                        print("✅ Cleared emergency contacts from API")
                    }
                )
                .store(in: &cancellables)
            return
        }
        
        let updates: [String: Any] = [
            "emergency_contact_name": primaryContact.name,
            "emergency_contact_phone": primaryContact.phoneNumber
        ]
        
        networkManager.updateProfile(updates)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to save emergency contacts: \(error)")
                    }
                },
                receiveValue: { _ in
                    print("✅ Saved primary emergency contact to API")
                }
            )
            .store(in: &cancellables)
    }
    
    private func playEmergencyAlert() {
        // Play emergency alert sound
        AudioServicesPlaySystemSound(1005) // Emergency alert tone
    }
    
    // MARK: - Manual Emergency Response
    func triggerEmergencyResponse() {
        // Immediately trigger emergency protocol without countdown
        safetyStatus = .emergency
        lastCrashAlert = Date()
        
        // Provide immediate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Play emergency alert
        playEmergencyAlert()
        
        // Send emergency alerts
        sendEmergencyAlerts()
        
        // Trigger Apple Watch emergency features
        NotificationCenter.default.post(name: .emergencyTriggered, object: nil)
        
        print("🚨 Manual emergency response triggered")
    }

    func loadICEPayload() -> EmergencyICEPayload? {
        // Map from stored medical info to ICE payload
        let defaults = UserDefaults.standard
        let bloodType = defaults.string(forKey: "medical_blood_type")
        let allergies = defaults.stringArray(forKey: "medical_allergies")
        let medications = defaults.stringArray(forKey: "medical_medications")
        let medicalID = defaults.string(forKey: "medical_id")
        let conditions = defaults.stringArray(forKey: "medical_conditions")
        let notes = defaults.string(forKey: "medical_emergency_notes")
        if bloodType == nil && (allergies?.isEmpty ?? true) && (medications?.isEmpty ?? true) && medicalID == nil && (conditions?.isEmpty ?? true) && (notes == nil) {
            return nil
        }
        return EmergencyICEPayload(
            bloodType: bloodType,
            allergies: allergies,
            medications: medications,
            medicalID: medicalID,
            conditions: conditions,
            emergencyNotes: notes
        )
    }
}

// Note: EmergencyContact is now defined in DataModels.swift to avoid conflicts

extension Foundation.Notification.Name {
    static let emergencyTriggered = Foundation.Notification.Name("emergencyTriggered")
    static let emergencyDetected = Foundation.Notification.Name("emergencyDetected")
    static let emergencyCountdownStarted = Foundation.Notification.Name("emergencyCountdownStarted")
} 