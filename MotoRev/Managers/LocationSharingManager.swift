import Foundation
import CoreLocation
import UserNotifications

class LocationSharingManager: ObservableObject {
    static let shared = LocationSharingManager()
    
    // MARK: - Published Properties
    @Published var sharingMode: SharingMode = .disabled
    @Published var packMembers: [PackMember] = []
    @Published var sharingRequests: [SharingRequest] = []
    @Published var activeShares: [ActiveShare] = []
    @Published var trustedContacts: [TrustedContact] = []
    
    // MARK: - Location Sharing Modes
    enum SharingMode: String, CaseIterable, Codable {
        case disabled = "disabled"
        case onRideOnly = "on_ride_only"
        case alwaysWithPack = "always_with_pack"
        case emergencyOnly = "emergency_only"
        
        var title: String {
            switch self {
            case .disabled: return "Disabled"
            case .onRideOnly: return "During Rides Only"
            case .alwaysWithPack: return "Always with Pack"
            case .emergencyOnly: return "Emergency Only"
            }
        }
        
        var description: String {
            switch self {
            case .disabled: return "Location is never shared"
            case .onRideOnly: return "Share location with pack members only during active rides"
            case .alwaysWithPack: return "Always share location with trusted pack members"
            case .emergencyOnly: return "Share location only during emergencies or SOS"
            }
        }
        
        var icon: String {
            switch self {
            case .disabled: return "location.slash"
            case .onRideOnly: return "location.circle"
            case .alwaysWithPack: return "location.circle.fill"
            case .emergencyOnly: return "sos"
            }
        }
    }
    
    private init() {
        loadSharingSettings()
        loadPackMembers()
        loadTrustedContacts()
        
        // Set default sharing mode if not set
        if sharingMode == .disabled {
            sharingMode = .onRideOnly
            saveSharingSettings()
        }
    }
    
    // MARK: - Core Location Sharing
    func shareLocation(with contact: TrustedContact, duration: TimeInterval? = nil) {
        // In a real app, this would get location from the app's LocationManager instance
        // For now, we'll create a default location (San Francisco)
        let defaultLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        let shareId = UUID()
        let share = ActiveShare(
            id: shareId,
            contactId: contact.id,
            contactName: contact.name,
            startTime: Date(),
            endTime: duration != nil ? Date().addingTimeInterval(duration!) : nil,
            lastLocation: defaultLocation.coordinate,
            lastUpdate: Date(),
            sharingLevel: determineSharingLevel(for: contact)
        )
        
        activeShares.append(share)
        
        // Send initial location
        sendLocationUpdate(for: share)
        
        // Save and notify
        saveActiveShares()
        notifyLocationShared(with: contact)
        
        print("📍 Started sharing location with \(contact.name)")
    }
    
    func stopSharing(with contactId: UUID) {
        activeShares.removeAll { $0.contactId == contactId }
        saveActiveShares()
        
        print("🛑 Stopped sharing location")
    }
    
    func updateSharedLocation() {
        // In a real app, this would get location from the app's LocationManager instance
        let defaultLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        for i in activeShares.indices {
            activeShares[i].lastLocation = defaultLocation.coordinate
            activeShares[i].lastUpdate = Date()
            
            // Check if share has expired
            if let endTime = activeShares[i].endTime, Date() > endTime {
                activeShares.remove(at: i)
                continue
            }
            
            sendLocationUpdate(for: activeShares[i])
        }
        
        saveActiveShares()
    }
    
    private func sendLocationUpdate(for share: ActiveShare) {
        // In a real implementation, this would send to a server
        // For now, we'll simulate the update
        print("📡 Location update sent to \(share.contactName)")
    }
    
    func enableLocationSharing() {
        // Enable location sharing based on current mode
        switch sharingMode {
        case .disabled:
            sharingMode = .onRideOnly
        case .onRideOnly, .alwaysWithPack, .emergencyOnly:
            break // Already enabled
        }
        
        applyLocationSharingRules()
        saveSharingSettings()
        
        print("📍 Location sharing enabled")
    }
    
    func disableLocationSharing() {
        // Stop all active shares
        activeShares.removeAll()
        saveActiveShares()
        
        // Set mode to disabled
        sharingMode = .disabled
        saveSharingSettings()
        
        print("🛑 Location sharing disabled")
    }
    
    // MARK: - Pack Management
    func inviteToGroup(_ username: String) -> Bool {
        // Check if user exists and isn't already in pack
        guard !packMembers.contains(where: { $0.username == username }) else {
            return false
        }
        
        let request = SharingRequest(
            id: UUID(),
            fromUserId: UUID(), // Current user's ID
            fromUsername: SocialManager.shared.currentUser?.username ?? "Unknown",
            toUsername: username,
            type: .packInvite,
            timestamp: Date(),
            status: .pending
        )
        
        sharingRequests.append(request)
        saveSharingRequests()
        
        print("📨 Pack invite sent to \(username)")
        return true
    }
    
    func acceptPackInvite(_ requestId: UUID) {
        guard let requestIndex = sharingRequests.firstIndex(where: { $0.id == requestId }) else { return }
        
        var request = sharingRequests[requestIndex]
        request.status = .accepted
        sharingRequests[requestIndex] = request
        
        // Add to pack
        let newMember = PackMember(
            id: UUID(),
            username: request.fromUsername,
            displayName: request.fromUsername,
            joinDate: Date(),
            trustLevel: .pack,
            isOnline: false,
            lastSeen: Date(),
            currentLocation: nil,
            isRiding: false
        )
        
        packMembers.append(newMember)
        
        savePackMembers()
        saveSharingRequests()
        
        print("✅ Accepted pack invite from \(request.fromUsername)")
    }
    
    func removeFromPack(_ memberId: UUID) {
        packMembers.removeAll { $0.id == memberId }
        savePackMembers()
        
        print("❌ Removed member from pack")
    }
    
    // MARK: - Trusted Contacts
    func addTrustedContact(_ contact: TrustedContact) {
        trustedContacts.append(contact)
        saveTrustedContacts()
        
        print("👥 Added trusted contact: \(contact.name)")
    }
    
    func updateTrustLevel(for contactId: UUID, to level: TrustLevel) {
        if let index = trustedContacts.firstIndex(where: { $0.id == contactId }) {
            trustedContacts[index].trustLevel = level
            saveTrustedContacts()
        }
    }
    
    // MARK: - Emergency Sharing
    func enableEmergencySharing() {
        // Share with all emergency contacts immediately
        for contact in SafetyManager.shared.emergencyContacts {
            let trustedContact = TrustedContact(
                id: contact.id,
                name: contact.name,
                phoneNumber: contact.phoneNumber,
                relationship: contact.relationship,
                trustLevel: .emergency,
                isEmergencyContact: true
            )
            
            shareLocation(with: trustedContact) // No duration = indefinite during emergency
        }
        
        print("🆘 Emergency location sharing enabled")
    }
    
    func disableEmergencySharing() {
        // Stop sharing with emergency contacts (unless they're also pack members)
        for contact in SafetyManager.shared.emergencyContacts {
            if !packMembers.contains(where: { $0.username == contact.name }) {
                stopSharing(with: contact.id)
            }
        }
        
        print("✅ Emergency location sharing disabled")
    }
    
    // MARK: - Privacy Controls
    private func determineSharingLevel(for contact: TrustedContact) -> SharingLevel {
        switch contact.trustLevel {
        case .emergency:
            return .precise // Emergency contacts get precise location
        case .family:
            return .precise
        case .pack:
            return .approximate // Pack members get approximate location
        case .friend:
            return .general // Friends get general area only
        }
    }
    
    func updateSharingMode(_ mode: SharingMode) {
        sharingMode = mode
        saveSharingSettings()
        
        // Apply new sharing rules
        applyLocationSharingRules()
        
        print("🔄 Location sharing mode updated to: \(mode.title)")
    }
    
    func applyLocationSharingRules() {
        switch sharingMode {
        case .disabled:
            // Stop all non-emergency sharing
            activeShares.removeAll { share in
                let contact = trustedContacts.first { $0.id == share.contactId }
                return contact?.trustLevel != .emergency
            }
            
        case .onRideOnly:
            // Only share during active rides
            let isRiding = false // In real app, would check LocationManager instance
            if !isRiding {
                activeShares.removeAll { share in
                    let contact = trustedContacts.first { $0.id == share.contactId }
                    return contact?.trustLevel != .emergency
                }
            }
            
        case .alwaysWithPack:
            // Always share with pack members
            for member in packMembers {
                if let trustedContact = trustedContacts.first(where: { $0.name == member.username }) {
                    if !activeShares.contains(where: { $0.contactId == trustedContact.id }) {
                        shareLocation(with: trustedContact)
                    }
                }
            }
            
        case .emergencyOnly:
            // Only emergency sharing
            activeShares.removeAll { share in
                let contact = trustedContacts.first { $0.id == share.contactId }
                return contact?.trustLevel != .emergency
            }
        }
    }
    
    // MARK: - Notifications
    private func notifyLocationShared(with contact: TrustedContact) {
        let content = UNMutableNotificationContent()
        content.title = "Location Sharing Started"
        content.body = "Now sharing your location with \(contact.name)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "location_share_\(contact.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Data Persistence
    private func saveSharingSettings() {
        UserDefaults.standard.set(sharingMode.rawValue, forKey: "locationSharingMode")
    }
    
    private func loadSharingSettings() {
        if let modeString = UserDefaults.standard.string(forKey: "locationSharingMode"),
           let mode = SharingMode(rawValue: modeString) {
            sharingMode = mode
        }
    }
    
    private func savePackMembers() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(packMembers)
            UserDefaults.standard.set(data, forKey: "packMembers")
        } catch {
            print("❌ Failed to save pack members: \(error)")
        }
    }
    
    private func loadPackMembers() {
        guard let data = UserDefaults.standard.data(forKey: "packMembers") else { return }
        
        do {
                            let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                packMembers = try decoder.decode([PackMember].self, from: data)
        } catch {
            print("❌ Failed to load pack members: \(error)")
        }
    }
    
    private func saveTrustedContacts() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(trustedContacts)
            UserDefaults.standard.set(data, forKey: "trustedContacts")
        } catch {
            print("❌ Failed to save trusted contacts: \(error)")
        }
    }
    
    private func loadTrustedContacts() {
        guard let data = UserDefaults.standard.data(forKey: "trustedContacts") else { return }
        
        do {
                            let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                trustedContacts = try decoder.decode([TrustedContact].self, from: data)
        } catch {
            print("❌ Failed to load trusted contacts: \(error)")
        }
    }
    
    private func saveActiveShares() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(activeShares)
            UserDefaults.standard.set(data, forKey: "activeShares")
        } catch {
            print("❌ Failed to save active shares: \(error)")
        }
    }
    
    private func saveSharingRequests() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(sharingRequests)
            UserDefaults.standard.set(data, forKey: "sharingRequests")
        } catch {
            print("❌ Failed to save sharing requests: \(error)")
        }
    }
}

// MARK: - Supporting Models
struct PackMember: Identifiable, Codable {
    let id: UUID
    let username: String
    let displayName: String
    let joinDate: Date
    var trustLevel: TrustLevel
    var isOnline: Bool
    var lastSeen: Date
    var currentLocation: CLLocationCoordinate2D?
    var isRiding: Bool
}

struct TrustedContact: Identifiable, Codable {
    let id: UUID
    let name: String
    let phoneNumber: String
    let relationship: String
    var trustLevel: TrustLevel
    let isEmergencyContact: Bool
    
    init(id: UUID = UUID(), name: String, phoneNumber: String, relationship: String, trustLevel: TrustLevel, isEmergencyContact: Bool = false) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.relationship = relationship
        self.trustLevel = trustLevel
        self.isEmergencyContact = isEmergencyContact
    }
}

struct SharingRequest: Identifiable, Codable {
    let id: UUID
    let fromUserId: UUID
    let fromUsername: String
    let toUsername: String
    let type: RequestType
    let timestamp: Date
    var status: RequestStatus
    
    enum RequestType: String, Codable {
        case packInvite = "pack_invite"
        case locationShare = "location_share"
        case emergencyContact = "emergency_contact"
    }
    
    enum RequestStatus: String, Codable {
        case pending = "pending"
        case accepted = "accepted"
        case declined = "declined"
        case expired = "expired"
    }
}

struct ActiveShare: Identifiable, Codable {
    let id: UUID
    let contactId: UUID
    let contactName: String
    let startTime: Date
    let endTime: Date?
    var lastLocation: CLLocationCoordinate2D
    var lastUpdate: Date
    let sharingLevel: SharingLevel
}

enum TrustLevel: String, CaseIterable, Codable {
    case emergency = "emergency"
    case family = "family"
    case pack = "pack"
    case friend = "friend"
    
    var title: String {
        switch self {
        case .emergency: return "Emergency Contact"
        case .family: return "Family"
        case .pack: return "Pack Member"
        case .friend: return "Friend"
        }
    }
    
    var color: String {
        switch self {
        case .emergency: return "red"
        case .family: return "blue"
        case .pack: return "green"
        case .friend: return "orange"
        }
    }
}

enum SharingLevel: String, Codable {
    case precise = "precise"       // Exact coordinates
    case approximate = "approximate" // Within ~100m
    case general = "general"       // City/neighborhood level
    
    var description: String {
        switch self {
        case .precise: return "Exact location"
        case .approximate: return "Approximate location"
        case .general: return "General area"
        }
    }
} 