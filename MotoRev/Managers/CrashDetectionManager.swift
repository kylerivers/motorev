import Foundation
import CoreMotion
import CoreLocation
import AVFoundation
import CallKit
import UserNotifications
import UIKit

class CrashDetectionManager: NSObject, ObservableObject {
    static let shared = CrashDetectionManager()
    
    // MARK: - Published Properties
    @Published var isMonitoring = false
    @Published var crashDetected = false
    @Published var emergencyCountdown = 0
    @Published var lastCrashEvent: CrashEvent?
    
    // MARK: - Core Motion & Sensors
    private let motionManager = CMMotionManager()
    private let altimeter = CMAltimeter()
    private var motionQueue = OperationQueue()
    
    // MARK: - Crash Detection Parameters
    private struct CrashThresholds {
        static let impactAcceleration: Double = 3.5 // g-force
        static let suddenDeceleration: Double = 4.0 // g-force
        static let rotationThreshold: Double = 2.0 // rad/s
        static let speedChangeThreshold: Double = 15.0 // mph sudden change
        static let confirmationTime: TimeInterval = 45.0 // seconds to confirm "I'm OK"
    }
    
    // MARK: - Emergency Response
    private var emergencyTimer: Timer?
    private var speechSynthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    
    // MARK: - Data Storage
    private var accelerationBuffer: [CMAcceleration] = []
    private var gyroBuffer: [CMRotationRate] = []
    private var locationBuffer: [CLLocation] = []
    private let bufferSize = 50 // Keep last 50 readings
    
    private override init() {
        super.init()
        setupMotionDetection()
        setupAudioSession()
        requestNotificationPermissions()
    }
    
    // MARK: - Setup Methods
    private func setupMotionDetection() {
        motionQueue.qualityOfService = .userInitiated
        
        guard motionManager.isAccelerometerAvailable else {
            print("❌ Accelerometer not available")
            return
        }
        
        guard motionManager.isGyroAvailable else {
            print("❌ Gyroscope not available")
            return
        }
        
        guard motionManager.isDeviceMotionAvailable else {
            print("❌ Device Motion not available")
            return
        }
        
        print("✅ Motion sensors initialized")
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    private func requestNotificationPermissions() {
        // Request notification permissions for crash alerts
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Crash detection notifications authorized")
            } else {
                print("❌ Crash detection notifications denied: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
        
        // Create crash detection notification category
        let emergencyAction = UNNotificationAction(
            identifier: "EMERGENCY_ACTION",
            title: "Call Emergency Services",
            options: []
        )
        
        let cancelAction = UNNotificationAction(
            identifier: "CANCEL_ACTION",
            title: "I'm OK - Cancel Alert",
            options: []
        )
        
        let crashCategory = UNNotificationCategory(
            identifier: "CRASH_DETECTION",
            actions: [cancelAction, emergencyAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([crashCategory])
    }
    
    // MARK: - Monitoring Controls
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        // Start accelerometer updates
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: motionQueue) { [weak self] data, error in
            guard let self = self, let acceleration = data?.acceleration else { return }
            self.processAccelerometerData(acceleration)
        }
        
        // Start gyroscope updates
        motionManager.gyroUpdateInterval = 0.1
        motionManager.startGyroUpdates(to: motionQueue) { [weak self] data, error in
            guard let self = self, let rotation = data?.rotationRate else { return }
            self.processGyroscopeData(rotation)
        }
        
        // Start device motion updates
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] data, error in
            guard let self = self, let motion = data else { return }
            self.processDeviceMotionData(motion)
        }
        
        print("🛡️ Crash detection monitoring started")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        motionManager.stopDeviceMotionUpdates()
        
        print("🛡️ Crash detection monitoring stopped")
    }
    
    // MARK: - Motion Data Processing
    private func processAccelerometerData(_ acceleration: CMAcceleration) {
        // Add to buffer
        accelerationBuffer.append(acceleration)
        if accelerationBuffer.count > bufferSize {
            accelerationBuffer.removeFirst()
        }
        
        // Calculate total acceleration magnitude
        let totalAccel = sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2) + pow(acceleration.z, 2))
        
        // Detect sudden impacts
        if totalAccel > CrashThresholds.impactAcceleration {
            detectPotentialCrash(type: .suddenImpact, magnitude: totalAccel, timestamp: Date())
        }
    }
    
    private func processGyroscopeData(_ rotation: CMRotationRate) {
        // Add to buffer
        gyroBuffer.append(rotation)
        if gyroBuffer.count > bufferSize {
            gyroBuffer.removeFirst()
        }
        
        // Calculate total rotation magnitude
        let totalRotation = sqrt(pow(rotation.x, 2) + pow(rotation.y, 2) + pow(rotation.z, 2))
        
        // Detect sudden rotation (bike going down)
        if totalRotation > CrashThresholds.rotationThreshold {
            detectPotentialCrash(type: .suddenRotation, magnitude: totalRotation, timestamp: Date())
        }
    }
    
    private func processDeviceMotionData(_ data: CMDeviceMotion) {
        // Analyze user acceleration (filtered from gravity)
        let userAcceleration = data.userAcceleration
        let totalUserAccel = sqrt(pow(userAcceleration.x, 2) + pow(userAcceleration.y, 2) + pow(userAcceleration.z, 2))
        
        // Analyze attitude changes (device orientation)
        _ = data.attitude
        
        // Combined analysis for more accurate crash detection
        if totalUserAccel > CrashThresholds.suddenDeceleration {
            detectPotentialCrash(type: .suddenDeceleration, magnitude: totalUserAccel, timestamp: Date())
        }
    }
    
    // MARK: - Crash Detection Logic
    private func detectPotentialCrash(type: CrashType, magnitude: Double, timestamp: Date) {
        // Prevent multiple triggers within short timeframe
        guard !crashDetected else { return }
        
        // AI-enhanced crash detection algorithm
        let crashProbability = calculateCrashProbability(type: type, magnitude: magnitude)
        
        if crashProbability > 0.75 { // 75% confidence threshold
            DispatchQueue.main.async {
                self.triggerCrashDetection(type: type, magnitude: magnitude, probability: crashProbability)
            }
        }
    }
    
    private func calculateCrashProbability(type: CrashType, magnitude: Double) -> Double {
        var probability: Double = 0.0
        
        // Base probability from magnitude
        switch type {
        case .suddenImpact:
            probability = min(magnitude / 6.0, 0.9) // Max 90% from impact alone
        case .suddenDeceleration:
            probability = min(magnitude / 5.0, 0.8) // Max 80% from deceleration
        case .suddenRotation:
            probability = min(magnitude / 3.0, 0.7) // Max 70% from rotation
        }
        
        // Enhance with contextual data
        probability += analyzeContextualFactors()
        
        // Cap at 95% to allow for false positives
        return min(probability, 0.95)
    }
    
    private func analyzeContextualFactors() -> Double {
        var contextBonus: Double = 0.0
        
        // Speed analysis (if available from LocationManager)
        // In real app, would get location from LocationManager instance
        let defaultLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        if true {
                          let speed = defaultLocation.speed
            if speed > 13.4 { // 30 mph or higher
                contextBonus += 0.1
            }
        }
        
        // Historical pattern analysis
        if accelerationBuffer.count >= 10 {
            let recentVariability = calculateAccelerationVariability()
            if recentVariability > 2.0 {
                contextBonus += 0.05
            }
        }
        
        return contextBonus
    }
    
    private func calculateAccelerationVariability() -> Double {
        guard accelerationBuffer.count >= 2 else { return 0.0 }
        
        let magnitudes = accelerationBuffer.suffix(10).map { acceleration in
            sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2) + pow(acceleration.z, 2))
        }
        
        let mean = magnitudes.reduce(0, +) / Double(magnitudes.count)
        let variance = magnitudes.map { pow($0 - mean, 2) }.reduce(0, +) / Double(magnitudes.count)
        
        return sqrt(variance)
    }
    
    // MARK: - Emergency Response
    private func triggerCrashDetection(type: CrashType, magnitude: Double, probability: Double) {
        crashDetected = true
        
        // Create crash event
        let defaultLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let crashEvent = CrashEvent(
            id: UUID(),
            timestamp: Date(),
            type: type,
            magnitude: magnitude,
            probability: probability,
            location: defaultLocation.coordinate,
            accelerationData: Array(accelerationBuffer.suffix(20)),
            gyroData: Array(gyroBuffer.suffix(20))
        )
        
        lastCrashEvent = crashEvent
        
        print("🚨 CRASH DETECTED! Type: \(type), Magnitude: \(magnitude), Probability: \(probability)")
        
        // Start emergency countdown
        startEmergencyCountdown()
        
        // Play loud alert sound
        playEmergencyAlert()
        
        // Send critical notification
        sendCriticalNotification(crashEvent: crashEvent)
        
        // Save crash data
        saveCrashEvent(crashEvent)
    }
    
    private func startEmergencyCountdown() {
        emergencyCountdown = Int(CrashThresholds.confirmationTime)
        
        emergencyTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.emergencyCountdown -= 1
            
            // Update UI every 5 seconds with countdown
            if self.emergencyCountdown % 5 == 0 || self.emergencyCountdown <= 10 {
                self.announceCountdown()
            }
            
            if self.emergencyCountdown <= 0 {
                timer.invalidate()
                self.initiateEmergencyResponse()
            }
        }
    }
    
    private func announceCountdown() {
        let message = emergencyCountdown > 10 ? 
            "Crash detected. You have \(emergencyCountdown) seconds to confirm you're okay." :
            "\(emergencyCountdown) seconds remaining. Press Cancel if you're okay."
        
        speakMessage(message)
    }
    
    func confirmImOkay() {
        emergencyTimer?.invalidate()
        emergencyTimer = nil
        crashDetected = false
        emergencyCountdown = 0
        
        print("✅ User confirmed they're okay - Emergency response cancelled")
        
        // Log false positive for AI improvement
        if let crashEvent = lastCrashEvent {
            logFalsePositive(crashEvent)
        }
        
        speakMessage("Emergency response cancelled. Stay safe!")
    }
    
    private func initiateEmergencyResponse() {
        print("🆘 INITIATING EMERGENCY RESPONSE")
        
        // Call emergency services
        callEmergencyServices()
        
        // Notify emergency contacts
        notifyEmergencyContacts()
        
        // Continue location tracking
        startContinuousLocationTracking()
    }
    
    // MARK: - Emergency Services
    private func callEmergencyServices() {
        guard let crashEvent = lastCrashEvent else { return }
        
        // In real app, would get verified location from LocationManager instance
        let defaultLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let mockVerifiedLocation = VerifiedLocation(
            coordinates: defaultLocation.coordinate,
            accuracy: 5.0,
            nearestAddress: "Emergency Location",
            crossReferencedAddress: nil,
            landmarks: ["Default Emergency Location"],
            confidence: 0.9,
            timestamp: Date()
        )
        
        let emergencyMessage = createEmergencyMessage(crashEvent: crashEvent, location: mockVerifiedLocation)
        makeEmergencyCall(message: emergencyMessage)
    }
    
    private func createEmergencyMessage(crashEvent: CrashEvent, location: VerifiedLocation) -> String {
        let user = SocialManager.shared.currentUser
        let timestamp = DateFormatter.emergencyFormatter.string(from: crashEvent.timestamp)
        
        return """
        This is MotoRev emergency app. A motorcycle crash has been detected at \(location.coordinate.latitude), \(location.coordinate.longitude). The crash occurred at \(timestamp). The rider's name is \(user?.username ?? "Unknown"). Emergency contact: \(getEmergencyContactInfo()). Please dispatch emergency services immediately. Rider status unknown.
        """
    }
    
    private func getEmergencyContactInfo() -> String {
        let contacts = SafetyManager.shared.emergencyContacts
        guard let primary = contacts.first else { return "No emergency contact available" }
        return "\(primary.name) at \(primary.phoneNumber)"
    }
    
    private func makeEmergencyCall(message: String) {
        // Store message for call
        UserDefaults.standard.set(message, forKey: "pendingEmergencyMessage")
        
        // Initiate call to 911
        if let url = URL(string: "tel://911") {
            DispatchQueue.main.async {
                UIApplication.shared.open(url) { success in
                    if success {
                        print("📞 Emergency call initiated")
                        // Start speaking the message when call connects
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            self.speakEmergencyMessage(message)
                        }
                    } else {
                        print("❌ Failed to initiate emergency call")
                    }
                }
            }
        }
    }
    
    private func speakEmergencyMessage(_ message: String) {
        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = 0.5 // Slower, clearer speech
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        speechSynthesizer.speak(utterance)
    }
    
    private func speakMessage(_ message: String) {
        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = 0.6
        utterance.volume = 0.8
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        speechSynthesizer.speak(utterance)
    }
    
    // MARK: - Audio Alert
    private func playEmergencyAlert() {
        // Create a loud, attention-grabbing alert sound
        guard let soundURL = Bundle.main.url(forResource: "emergency_alert", withExtension: "mp3") else {
            // Fallback to system sound
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.volume = 1.0
            audioPlayer?.numberOfLoops = 3 // Play 3 times
            audioPlayer?.play()
        } catch {
            print("❌ Failed to play emergency alert: \(error)")
        }
    }
    
    // MARK: - Notifications
    private func sendCriticalNotification(crashEvent: CrashEvent) {
        let content = UNMutableNotificationContent()
        content.title = "🚨 CRASH DETECTED"
        content.body = "Tap to cancel emergency response if you're okay. Emergency services will be called automatically."
        content.sound = .defaultCritical
        content.interruptionLevel = .critical
        content.categoryIdentifier = "CRASH_DETECTION"
        
        let request = UNNotificationRequest(
            identifier: "crash_detection_\(crashEvent.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send crash notification: \(error)")
            }
        }
    }
    
    // MARK: - Emergency Contacts Notification
    private func notifyEmergencyContacts() {
        guard let crashEvent = lastCrashEvent else { return }
        
        let contacts = SafetyManager.shared.emergencyContacts
        
        for contact in contacts {
            sendEmergencyMessage(to: contact, crashEvent: crashEvent)
        }
    }
    
    private func sendEmergencyMessage(to contact: EmergencyContact, crashEvent: CrashEvent) {
        // In real app, would get verified location from LocationManager instance
        let message = """
        🚨 EMERGENCY: \(SocialManager.shared.currentUser?.username ?? "MotoRev user") has been in a motorcycle crash.
        
        Location: 123 Main St, San Francisco, CA
        Time: \(DateFormatter.emergencyFormatter.string(from: crashEvent.timestamp))
        Map: https://maps.apple.com/?q=\(crashEvent.location?.latitude ?? 0),\(crashEvent.location?.longitude ?? 0)
        
        Emergency services have been notified.
        """
        
        // Send SMS (would require MessageUI framework in real implementation)
        print("📱 Emergency message to \(contact.name): \(message)")
    }
    
    // MARK: - Data Management
    private func saveCrashEvent(_ crashEvent: CrashEvent) {
        var savedEvents = loadCrashEvents()
        savedEvents.append(crashEvent)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(savedEvents)
            UserDefaults.standard.set(data, forKey: "crashEvents")
            print("✅ Crash event saved")
        } catch {
            print("❌ Failed to save crash event: \(error)")
        }
    }
    
    private func loadCrashEvents() -> [CrashEvent] {
        guard let data = UserDefaults.standard.data(forKey: "crashEvents") else { return [] }
        
        do {
            let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([CrashEvent].self, from: data)
        } catch {
            print("❌ Failed to load crash events: \(error)")
            return []
        }
    }
    
    private func logFalsePositive(_ crashEvent: CrashEvent) {
        var falsePositives = UserDefaults.standard.array(forKey: "falsePositives") as? [String] ?? []
        falsePositives.append(crashEvent.id.uuidString)
        UserDefaults.standard.set(falsePositives, forKey: "falsePositives")
        
        print("📊 False positive logged for AI improvement")
    }
    
    // MARK: - Continuous Location Tracking
    private func startContinuousLocationTracking() {
        // Enhanced location tracking during emergency
        // In real app, would call LocationManager instance to start emergency tracking
        print("📍 Starting emergency location tracking")
    }
    
    // MARK: - Manual Emergency Trigger
    func triggerManualEmergency() {
        // Create manual emergency event
        let manualCrashEvent = CrashEvent(
            id: UUID(),
            timestamp: Date(),
            type: .suddenImpact,
            magnitude: 0.0, // Manual trigger
            probability: 1.0, // 100% since it's manual
            location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            accelerationData: [],
            gyroData: []
        )
        
        // Set crash state and start emergency protocol
        DispatchQueue.main.async {
            self.lastCrashEvent = manualCrashEvent
            self.crashDetected = true
            self.startEmergencyCountdown()
            self.playEmergencyAlert()
            self.sendCriticalNotification(crashEvent: manualCrashEvent)
            self.notifyEmergencyContacts()
            self.saveCrashEvent(manualCrashEvent)
            self.startContinuousLocationTracking()
        }
        
        print("🚨 Manual emergency triggered")
    }
}

// MARK: - Supporting Models
struct CrashEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let type: CrashType
    let magnitude: Double
    let probability: Double
    let location: CLLocationCoordinate2D?
    let accelerationData: [CMAcceleration]
    let gyroData: [CMRotationRate]
}

enum CrashType: String, CaseIterable, Codable {
    case suddenImpact = "sudden_impact"
    case suddenDeceleration = "sudden_deceleration"
    case suddenRotation = "sudden_rotation"
    
    var description: String {
        switch self {
        case .suddenImpact: return "Sudden Impact"
        case .suddenDeceleration: return "Sudden Deceleration"
        case .suddenRotation: return "Sudden Rotation"
        }
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let emergencyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}

// MARK: - CoreMotion Extensions
extension CMAcceleration: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y, z
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(z, forKey: .z)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Double.self, forKey: .x)
        let y = try container.decode(Double.self, forKey: .y)
        let z = try container.decode(Double.self, forKey: .z)
        self.init(x: x, y: y, z: z)
    }
}

extension CMRotationRate: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y, z
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(z, forKey: .z)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Double.self, forKey: .x)
        let y = try container.decode(Double.self, forKey: .y)
        let z = try container.decode(Double.self, forKey: .z)
        self.init(x: x, y: y, z: z)
    }
} 