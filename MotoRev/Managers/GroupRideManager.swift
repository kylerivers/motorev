import Foundation
import CoreLocation
import Combine
import Network

class GroupRideManager: ObservableObject {
    static let shared = GroupRideManager()
    
    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    
    // MARK: - Published Properties
    @Published var currentGroupRide: GroupRide?
    @Published var groupMembers: [GroupMember] = []
    @Published var isInGroupRide = false
    @Published var hasActiveInvite = false
    @Published var rideInvitations: [RideInvitation] = []
    @Published var leaderboardData: [GroupMember] = []
    @Published var sharedRoute: SharedRoute?
    @Published var groupMessages: [GroupMessage] = []
    
    // MARK: - Location Tracking
    @Published var isLocationSharingEnabled = true
    private var lastLocationUpdate = Date()
    private let locationUpdateInterval: TimeInterval = 3.0 // 3 seconds for pack tracking
    
    // MARK: - Connection Status
    @Published var isConnected = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    private init() {
        setupNetworkMonitoring()
        startPollingTimer()
    }
    
    // MARK: - Setup
    private func setupNetworkMonitoring() {
        networkManager.$isLoggedIn
            .sink { [weak self] isLoggedIn in
                if isLoggedIn {
                    self?.connectionStatus = .connected
                    self?.isConnected = true
                } else {
                    self?.connectionStatus = .disconnected
                    self?.isConnected = false
                }
            }
            .store(in: &cancellables)
    }
    
    private func startPollingTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: locationUpdateInterval, repeats: true) { [weak self] _ in
            if self?.isInGroupRide == true {
                self?.pollGroupRideUpdates()
            }
        }
    }
    
    private func pollGroupRideUpdates() {
        guard let groupRide = currentGroupRide else { return }
        fetchGroupRideDetails(groupRide.id)
        updateMemberDistances()
        fetchSharedRoute()
    }
    
    private func updateMemberDistances() {
        guard let _ = networkManager.currentUser,
              let myLocation = LocationManager.shared.location else { return }
        
        // Update distances from current user to all members
        for i in 0..<groupMembers.count {
            if let memberLocation = groupMembers[i].lastLocation {
                let memberCLLocation = CLLocation(
                    latitude: memberLocation.latitude,
                    longitude: memberLocation.longitude
                )
                let distance = myLocation.distance(from: memberCLLocation)
                
                // Update the member with calculated distance
                let updatedMember = groupMembers[i]
                // Note: Since GroupMember is a struct with let properties,
                // in a real implementation we'd need mutable distance properties
                // or separate tracking. For now, we use the existing distanceFromLeader field
                groupMembers[i] = GroupMember(
                    id: updatedMember.id,
                    userId: updatedMember.userId,
                    username: updatedMember.username,
                    firstName: updatedMember.firstName,
                    lastName: updatedMember.lastName,
                    profilePictureUrl: updatedMember.profilePictureUrl,
                    role: updatedMember.role,
                    joinedAt: updatedMember.joinedAt,
                    isOnline: updatedMember.isOnline,
                    lastLocation: updatedMember.lastLocation,
                    distanceFromLeader: distance,
                    safetyScore: updatedMember.safetyScore
                )
            }
        }
    }
    
    // MARK: - Group Ride Management
    func createGroupRide(name: String, description: String? = nil, maxMembers: Int = 10, isPrivate: Bool = false, completion: @escaping (Result<GroupRide, Error>) -> Void) {
        let createRequest = CreateGroupRideRequest(
            name: name,
            description: description,
            maxMembers: maxMembers,
            isPrivate: isPrivate
        )
        
        makeAuthenticatedRequest(
            endpoint: "/api/group-rides",
            method: "POST",
            body: createRequest
        ) { [weak self] (result: Result<GroupRide, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let groupRide):
                    self?.currentGroupRide = groupRide
                    self?.isInGroupRide = true
                    completion(.success(groupRide))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func joinGroupRide(_ rideId: String, completion: @escaping (Result<GroupRide, Error>) -> Void) {
        makeAuthenticatedRequest(
            endpoint: "/api/group-rides/\(rideId)/join",
            method: "POST"
        ) { [weak self] (result: Result<GroupRide, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let groupRide):
                    self?.currentGroupRide = groupRide
                    self?.isInGroupRide = true
                    completion(.success(groupRide))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func leaveGroupRide(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let groupRide = currentGroupRide else {
            completion(.failure(NSError(domain: "GroupRideManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No active group ride"])))
            return
        }
        
        makeAuthenticatedRequest(
            endpoint: "/api/group-rides/\(groupRide.id)/leave",
            method: "POST"
        ) { [weak self] (result: Result<EmptyResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.currentGroupRide = nil
                    self?.isInGroupRide = false
                    self?.groupMembers = []
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func fetchGroupRideDetails(_ rideId: String) {
        makeAuthenticatedRequest(
            endpoint: "/api/group-rides/\(rideId)",
            method: "GET"
        ) { [weak self] (result: Result<GroupRideDetailsResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.currentGroupRide = response.groupRide
                    self?.groupMembers = response.members
                case .failure(let error):
                    print("Failed to fetch group ride details: \(error)")
                }
            }
        }
    }
    
    // MARK: - Location Sharing
    func updateLocation(_ location: CLLocation) {
        guard isInGroupRide,
              isLocationSharingEnabled,
              let groupRide = currentGroupRide,
              Date().timeIntervalSince(lastLocationUpdate) >= locationUpdateInterval else { return }
        
        let locationUpdate = LocationUpdate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            heading: location.course,
            speed: location.speed
        )
        
        makeAuthenticatedRequest(
            endpoint: "/api/group-rides/\(groupRide.id)/location",
            method: "POST",
            body: locationUpdate
        ) { [weak self] (result: Result<EmptyResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.lastLocationUpdate = Date()
                case .failure(let error):
                    print("Failed to update location: \(error)")
                }
            }
        }
    }
    
    // MARK: - Route Sharing
    func shareRoute(_ route: SharedRoute, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let groupRide = currentGroupRide else {
            completion(.failure(NSError(domain: "GroupRideManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No active group ride"])))
            return
        }
        
        makeAuthenticatedRequest(
            endpoint: "/api/group-rides/\(groupRide.id)/route",
            method: "POST",
            body: route
        ) { [weak self] (result: Result<EmptyResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.sharedRoute = route
                    self?.notifyMembersOfRouteUpdate(route)
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func acceptSharedRoute(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let sharedRoute = sharedRoute else {
            completion(.failure(NSError(domain: "GroupRideManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No shared route available"])))
            return
        }
        
        // Apply the shared route to LocationManager
        LocationManager.shared.applySharedRoute(sharedRoute)
        completion(.success(()))
    }
    
    func fetchSharedRoute() {
        guard let groupRide = currentGroupRide else { return }
        
        makeAuthenticatedRequest(
            endpoint: "/api/group-rides/\(groupRide.id)/route",
            method: "GET"
        ) { [weak self] (result: Result<SharedRoute, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let route):
                    self?.sharedRoute = route
                case .failure(let error):
                    print("Failed to fetch shared route: \(error)")
                }
            }
        }
    }
    
    private func notifyMembersOfRouteUpdate(_ route: SharedRoute) {
        // Send notification to group members about route update
        let message = "Leader shared a new route: \(route.name)"
        sendMessage(message) { _ in }
    }
    
    // MARK: - Messaging
    func sendMessage(_ content: String, completion: @escaping (Result<GroupMessage, Error>) -> Void) {
        guard let groupRide = currentGroupRide else {
            completion(.failure(NSError(domain: "GroupRideManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No active group ride"])))
            return
        }
        
        let messageRequest = SendMessageRequest(content: content)
        
        makeAuthenticatedRequest(
            endpoint: "/api/group-rides/\(groupRide.id)/messages",
            method: "POST",
            body: messageRequest
        ) { [weak self] (result: Result<GroupMessage, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let message):
                    self?.groupMessages.append(message)
                    completion(.success(message))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Invitations
    func inviteUser(_ userId: String, completion: @escaping (Result<RideInvitation, Error>) -> Void) {
        guard let groupRide = currentGroupRide else {
            completion(.failure(NSError(domain: "GroupRideManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No active group ride"])))
            return
        }
        
        let inviteRequest = InviteUserRequest(userId: userId)
        
        makeAuthenticatedRequest(
            endpoint: "/api/group-rides/\(groupRide.id)/invite",
            method: "POST",
            body: inviteRequest
        ) { (result: Result<RideInvitation, Error>) in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    func fetchPendingInvitations() {
        makeAuthenticatedRequest(
            endpoint: "/api/group-rides/invitations",
            method: "GET"
        ) { [weak self] (result: Result<[RideInvitation], Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let invitations):
                    self?.rideInvitations = invitations
                    self?.hasActiveInvite = !invitations.isEmpty
                case .failure(let error):
                    print("Failed to fetch invitations: \(error)")
                }
            }
        }
    }
    
    func respondToInvitation(_ invitationId: String, accept: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        let response = InvitationResponse(accept: accept)
        
        makeAuthenticatedRequest(
            endpoint: "/api/group-rides/invitations/\(invitationId)/respond",
            method: "POST",
            body: response
        ) { [weak self] (result: Result<EmptyResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.fetchPendingInvitations()
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Cleanup
    deinit {
        updateTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Request/Response Models
struct CreateGroupRideRequest: Codable {
    let name: String
    let description: String?
    let maxMembers: Int?
    let isPrivate: Bool?
}

struct LocationUpdate: Codable {
    let latitude: Double
    let longitude: Double
    let heading: Double
    let speed: Double
}

struct SendMessageRequest: Codable {
    let content: String
}

struct InviteUserRequest: Codable {
    let userId: String
}

struct InvitationResponse: Codable {
    let accept: Bool
}

struct GroupRideDetailsResponse: Codable, Sendable {
    let groupRide: GroupRide
    let members: [GroupMember]
}

struct EmptyResponse: Codable, Sendable {}

// MARK: - GroupRideManager Network Extension
extension GroupRideManager {
    private func makeAuthenticatedRequest<T: Codable, U: Codable>(
        endpoint: String,
        method: String,
        body: T,
        completion: @escaping (Result<U, Error>) -> Void
    ) where U: Sendable {
        guard let token = networkManager.authToken else {
            completion(.failure(NSError(domain: "GroupRideManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authentication token"])))
            return
        }
        
        guard let url = URL(string: "http://192.168.68.78:3000\(endpoint)") else {
            completion(.failure(NSError(domain: "GroupRideManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "GroupRideManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(U.self, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func makeAuthenticatedRequest<U: Codable>(
        endpoint: String,
        method: String,
        completion: @escaping (Result<U, Error>) -> Void
    ) where U: Sendable {
        makeAuthenticatedRequest(endpoint: endpoint, method: method, body: EmptyBody(), completion: completion)
    }
} 