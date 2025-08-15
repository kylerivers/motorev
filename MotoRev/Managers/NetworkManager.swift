import Foundation
import Combine
import CoreLocation // Added for CLLocationCoordinate2D

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    // Use production API base URL for all builds to ensure device connectivity
    let baseURL = "https://motorev-prod-production.up.railway.app/api"
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    @Published var authToken: String?
    
    private init() {
        loadStoredAuth()
        // No auto-login in production builds. Users must authenticate against the real backend.
    }
    
    // MARK: - Authentication Methods
    
    func register(username: String, email: String, password: String, firstName: String, lastName: String, phoneNumber: String?, motorcycleMake: String?, motorcycleModel: String?, motorcycleYear: String?, ridingExperience: String) -> AnyPublisher<AuthResponse, Error> {
        let url = URL(string: "\(baseURL)/auth/register")!
        
        let body = RegisterRequest(
            username: username,
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            phoneNumber: phoneNumber,
            motorcycleMake: motorcycleMake,
            motorcycleModel: motorcycleModel,
            motorcycleYear: motorcycleYear,
            ridingExperience: ridingExperience
        )
        
        return makeRequest(url: url, method: "POST", body: body)
            .handleEvents(receiveOutput: { [weak self] response in
                self?.handleAuthSuccess(response)
            })
            .eraseToAnyPublisher()
    }
    
    func login(username: String, password: String) -> AnyPublisher<AuthResponse, Error> {
        let url = URL(string: "\(baseURL)/auth/login")!
        
        let body = LoginRequest(username: username, password: password)
        
        return makeRequest(url: url, method: "POST", body: body)
            .handleEvents(receiveOutput: { [weak self] response in
                self?.handleAuthSuccess(response)
            })
            .eraseToAnyPublisher()
    }
    
    func logout() -> AnyPublisher<MessageResponse, Error> {
        let url = URL(string: "\(baseURL)/auth/logout")!
        
        return makeAuthenticatedRequest(url: url, method: "POST", body: EmptyBody())
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.handleLogout()
            })
            .eraseToAnyPublisher()
    }
    
    func forceLogout() {
        handleLogout()
        print("🔑 Force logout completed")
    }
    
    func getCurrentUser() -> AnyPublisher<User, Error> {
        let url = URL(string: "\(baseURL)/auth/me")!
        return makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
            .map { (response: UserResponse) -> User in
                // Convert BackendUser to User
                return User(
                    id: UUID(), // Generate new UUID for app
                    username: response.user.username,
                    email: response.user.email,
                    firstName: response.user.firstName,
                    lastName: response.user.lastName,
                    phone: response.user.phone,
                    bio: response.user.bio ?? "",
                    bike: "\(response.user.motorcycleMake ?? "") \(response.user.motorcycleModel ?? "")".trimmingCharacters(in: .whitespaces),
                    motorcycleMake: response.user.motorcycleMake,
                    motorcycleModel: response.user.motorcycleModel,
                    motorcycleYear: response.user.motorcycleYear,
                    ridingExperience: User.RidingExperience(rawValue: response.user.ridingExperience ?? "beginner") ?? .beginner,
                    stats: UserStats(),
                    postsCount: response.user.postsCount ?? 0,
                    followersCount: response.user.followersCount ?? 0,
                    followingCount: response.user.followingCount ?? 0,
                    status: User.UserStatus(rawValue: response.user.status ?? "offline") ?? .offline,
                    locationSharingEnabled: response.user.locationSharingEnabled ?? false,
                    isVerified: response.user.isVerified ?? false,
                    followers: [],
                    following: [],
                    badges: [],
                    rank: 999,
                    joinDate: Date()
                )
            }
            .eraseToAnyPublisher()
    }
    
    func getCurrentUserRaw() -> AnyPublisher<UserResponse, Error> {
        let url = URL(string: "\(baseURL)/auth/me")!
        return makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
    }
    
    // MARK: - User Methods
    
    func updateProfile(
        firstName: String? = nil,
        lastName: String? = nil,
        phoneNumber: String? = nil,
        motorcycleMake: String? = nil,
        motorcycleModel: String? = nil,
        motorcycleYear: String? = nil,
        ridingExperience: String? = nil,
        bio: String? = nil,
        profilePicture: String? = nil
    ) -> AnyPublisher<UpdateProfileResponse, Error> {
        let url = URL(string: "\(baseURL)/users/profile")!
        
        // Convert base64 image to data URL format if needed
        var profilePictureData: String? = profilePicture
        if let picture = profilePicture, !picture.isEmpty {
            if !picture.hasPrefix("data:image/") && picture.count > 100 {
                // Assume it's base64 data, add proper data URL prefix
                profilePictureData = "data:image/jpeg;base64,\(picture)"
            }
        }
        
        let body = UpdateProfileRequest(
            firstName: firstName,
            lastName: lastName,
            phoneNumber: phoneNumber,
            motorcycleMake: motorcycleMake,
            motorcycleModel: motorcycleModel,
            motorcycleYear: motorcycleYear,
            ridingExperience: ridingExperience,
            bio: bio,
            profilePicture: profilePictureData
        )
        
        return makeAuthenticatedRequest(url: url, method: "PUT", body: body)
    }
    
    // MARK: - Search Methods
    
    func searchPosts(query: String, limit: Int = 20, offset: Int = 0) -> AnyPublisher<PostsResponse, Error> {
        let url = URL(string: "\(baseURL)/social/search/posts?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&limit=\(limit)&offset=\(offset)")!
        return makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
    }
    
    func searchStories(query: String, limit: Int = 20, offset: Int = 0) -> AnyPublisher<StoriesResponse, Error> {
        let url = URL(string: "\(baseURL)/social/search/stories?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&limit=\(limit)&offset=\(offset)")!
        return makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
    }
    
    func searchUsersGeneral(query: String, limit: Int = 20, offset: Int = 0) -> AnyPublisher<SearchUsersResponse, Error> {
        let url = URL(string: "\(baseURL)/social/search/users?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&limit=\(limit)&offset=\(offset)")!
        return makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
    }
    
    func searchPacks(query: String, limit: Int = 20, offset: Int = 0) -> AnyPublisher<PacksResponse, Error> {
        let url = URL(string: "\(baseURL)/social/search/packs?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&limit=\(limit)&offset=\(offset)")!
        return makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
    }
    
    func searchRides(query: String, limit: Int = 20, offset: Int = 0) -> AnyPublisher<SearchRidesResponse, Error> {
        let url = URL(string: "\(baseURL)/rides/search?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&limit=\(limit)&offset=\(offset)")!
        return makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
    }
    
    func searchAll(query: String, limit: Int = 10) -> AnyPublisher<GeneralSearchResponse, Error> {
        let url = URL(string: "\(baseURL)/social/search?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&limit=\(limit)")!
        return makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
    }
    
    func getSearchSuggestions(query: String, limit: Int = 5) -> AnyPublisher<SearchSuggestionsResponse, Error> {
        let url = URL(string: "\(baseURL)/social/search/suggestions?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&limit=\(limit)")!
        return makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
    }
    
    func getUserByUsername(_ username: String) -> AnyPublisher<UserResponse, Error> {
        let url = URL(string: "\(baseURL)/users/username/\(username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")")!
        return makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
    }
    
    // MARK: - Social Methods
    
    func getSocialFeed() -> AnyPublisher<[Post], Error> {
        return getFeed()
            .map { $0.posts }
            .eraseToAnyPublisher()
    }
    
    func getFeed(limit: Int = 20, offset: Int = 0) -> AnyPublisher<PostsResponse, Error> {
        let url = URL(string: "\(baseURL)/social/feed?limit=\(limit)&offset=\(offset)")!
        return makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
    }
    
    func createPost(content: String?, imageUrl: String?, location: CLLocationCoordinate2D?, rideId: String?) -> AnyPublisher<Post, Error> {
        let locationString = location != nil ? "\(location!.latitude),\(location!.longitude)" : nil
        return createPost(content: content, imageUrl: imageUrl, videoUrl: nil, location: locationString, rideId: rideId)
            .map { $0.post }
            .eraseToAnyPublisher()
    }
    
    func createPost(content: String?, imageUrl: String?, videoUrl: String?, location: String?, rideId: String?) -> AnyPublisher<PostResponse, Error> {
        let url = URL(string: "\(baseURL)/social/posts")!
        
        let body = CreatePostRequest(
            content: content,
            imageUrl: imageUrl,
            videoUrl: videoUrl,
            location: location,
            rideId: rideId
        )
        
        return makeAuthenticatedRequest(url: url, method: "POST", body: body)
    }
    
    func likePost(postId: String) -> AnyPublisher<MessageResponse, Error> {
        let url = URL(string: "\(baseURL)/social/posts/\(postId)/like")!
        return makeAuthenticatedRequest(url: url, method: "POST", body: EmptyBody())
    }
    
    func getComments(for postId: String) -> AnyPublisher<[Comment], Error> {
        let url = URL(string: "\(baseURL)/social/posts/\(postId)/comments")!
        return makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
            .map { (response: CommentsResponse) in
                return response.comments ?? []
            }
            .eraseToAnyPublisher()
    }
    
    func addComment(to postId: String, content: String) -> AnyPublisher<Comment, Error> {
        let url = URL(string: "\(baseURL)/social/posts/\(postId)/comments")!
        
        let body = AddCommentRequest(content: content)
        
        return makeAuthenticatedRequest(url: url, method: "POST", body: body)
            .map { (response: CommentResponse) in
                return response.comment
            }
            .eraseToAnyPublisher()
    }
    
    func sharePost(postId: String, caption: String? = nil) -> AnyPublisher<Post, Error> {
        let url = URL(string: "\(baseURL)/social/posts/\(postId)/share")!
        
        let body = SharePostRequest(caption: caption)
        
        return makeAuthenticatedRequest(url: url, method: "POST", body: body)
            .map { (response: PostResponse) in
                return response.post
            }
            .eraseToAnyPublisher()
    }
    
    func followUser(userId: String) -> AnyPublisher<MessageResponse, Error> {
        let url = URL(string: "\(baseURL)/social/follow/\(userId)")!
        return makeAuthenticatedRequest(url: url, method: "POST", body: EmptyBody())
    }
    
    // MARK: - Ride Methods
    
    func startRide(title: String?, startLocation: String?, plannedRoute: String?) -> AnyPublisher<RideResponse, Error> {
        let url = URL(string: "\(baseURL)/rides/start")!
        
        let body = StartRideRequest(
            title: title,
            startLocation: startLocation,
            plannedRoute: plannedRoute
        )
        
        return makeAuthenticatedRequest(url: url, method: "POST", body: body)
    }
    
    func updateRideLocation(rideId: String, latitude: Double, longitude: Double, speed: Double?, heading: Double?, accuracy: Double?) -> AnyPublisher<MessageResponse, Error> {
        let url = URL(string: "\(baseURL)/rides/\(rideId)/location")!
        
        let body = LocationUpdateRequest(
            latitude: latitude,
            longitude: longitude,
            speed: speed,
            heading: heading,
            accuracy: accuracy
        )
        
        return makeAuthenticatedRequest(url: url, method: "POST", body: body)
    }
    
    func completeRide(rideId: String, endLocation: String?, distance: Double?, duration: Int?, averageSpeed: Double?, maxSpeed: Double?, safetyScore: Int?) -> AnyPublisher<RideResponse, Error> {
        let url = URL(string: "\(baseURL)/rides/\(rideId)/complete")!
        
        let body = CompleteRideRequest(
            endLocation: endLocation,
            distance: distance,
            duration: duration,
            averageSpeed: averageSpeed,
            maxSpeed: maxSpeed,
            safetyScore: safetyScore
        )
        
        return makeAuthenticatedRequest(url: url, method: "POST", body: body)
    }
    
    func getRideHistory(limit: Int = 20, offset: Int = 0, status: String? = nil) -> AnyPublisher<RidesResponse, Error> {
        var urlString = "\(baseURL)/rides/history?limit=\(limit)&offset=\(offset)"
        if let status = status {
            urlString += "&status=\(status)"
        }
        let url = URL(string: urlString)!
        return makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
    }
    
    // MARK: - Safety Methods
    
    func reportEmergency(type: String, severity: String, location: String, description: String?, automaticDetection: Bool = false, sensorData: String?) -> AnyPublisher<EmergencyResponse, Error> {
        let url = URL(string: "\(baseURL)/safety/emergency")!
        
        let body = EmergencyRequest(
            type: type,
            severity: severity,
            location: location,
            description: description,
            automaticDetection: automaticDetection,
            sensorData: sensorData
        )
        
        return makeAuthenticatedRequest(url: url, method: "POST", body: body)
    }
    
    func reportHazard(type: String, location: String, description: String?, severity: String?, images: [String]?) -> AnyPublisher<HazardResponse, Error> {
        let url = URL(string: "\(baseURL)/safety/hazards")!
        
        let body = HazardRequest(
            type: type,
            location: location,
            description: description,
            severity: severity,
            images: images
        )
        
        return makeAuthenticatedRequest(url: url, method: "POST", body: body)
    }
    
    // MARK: - Missing Methods for SafetyManager and LocationManager
    
    func reportEmergencyEvent(eventType: String, severity: String, latitude: Double, longitude: Double, description: String) -> AnyPublisher<EmergencyResponse, Error> {
        return reportEmergency(
            type: eventType,
            severity: severity,
            location: "\(latitude),\(longitude)",
            description: description,
            automaticDetection: true,
            sensorData: nil
        )
    }
    
    func createRide(startTime: Date, endTime: Date, distance: Double, maxSpeed: Double, avgSpeed: Double, startLocation: CLLocationCoordinate2D?, endLocation: CLLocationCoordinate2D?) -> AnyPublisher<Ride, Error> {
        let url = URL(string: "\(baseURL)/rides/create")!
        
        let body = CreateRideRequest(
            startTime: startTime,
            endTime: endTime,
            distance: distance,
            maxSpeed: maxSpeed,
            avgSpeed: avgSpeed,
            startLocation: startLocation.map { "\($0.latitude),\($0.longitude)" },
            endLocation: endLocation.map { "\($0.latitude),\($0.longitude)" }
        )
        
        return makeAuthenticatedRequest(url: url, method: "POST", body: body)
            .map { (response: CreateRideResponse) in
                // Convert CreateRideResponse to Ride model
                return Ride(
                    id: response.ride.id,
                    userId: nil,
                    title: nil,
                    date: response.ride.startTime,
                    distance: response.ride.distance,
                    duration: response.ride.endTime.timeIntervalSince(response.ride.startTime),
                    averageSpeed: response.ride.avgSpeed,
                    maxSpeed: response.ride.maxSpeed,
                    startLocation: response.ride.startLocation ?? "",
                    endLocation: response.ride.endLocation ?? "",
                    safetyScore: response.ride.safetyScore ?? 100
                )
            }
            .eraseToAnyPublisher()
    }
    
    func updateProfile(_ updates: [String: Any]) -> AnyPublisher<UserUpdateResponse, Error> {
        let url = URL(string: "\(baseURL)/users/profile")!
        
        // Convert dictionary to proper request body
        let body = DictionaryBody(data: updates)
        
        return makeAuthenticatedRequest(url: url, method: "PUT", body: body)
    }
    
    func getNearbyRiders(latitude: Double, longitude: Double, radius: Int) -> AnyPublisher<[NearbyRider], Error> {
        let url = URL(string: "\(baseURL)/location/nearby?latitude=\(latitude)&longitude=\(longitude)&radius=\(radius)")!
        
        return makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
            .map { (response: NearbyRidersResponse) in
                return response.riders?.map { rider in
                    NearbyRider(
                        id: rider.id,
                        name: rider.name,
                        bike: rider.bike,
                        location: CLLocationCoordinate2D(latitude: rider.latitude, longitude: rider.longitude),
                        distance: rider.distance,
                        isRiding: rider.isRiding,
                        lastSeen: rider.lastSeen
                    )
                } ?? []
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Post Interactions
    func togglePostLike(postId: String) -> AnyPublisher<LikeResponse, Error> {
        let url = URL(string: "\(baseURL)/social/posts/\(postId)/like")!
        
        return makeAuthenticatedRequest(url: url, method: "POST", body: EmptyBody())
    }
    
    // MARK: - Bike Management
    func getBikes() -> AnyPublisher<BikesResponse, Error> {
        let url = URL(string: "\(baseURL)/bikes")!
        
        return makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
    }
    
    func createBike(bike: CreateBikeRequest) -> AnyPublisher<BikeResponse, Error> {
        let url = URL(string: "\(baseURL)/bikes")!
        
        return makeAuthenticatedRequest(url: url, method: "POST", body: bike)
    }
    
    func updateBike(bikeId: String, bike: UpdateBikeRequest) -> AnyPublisher<BikeResponse, Error> {
        let url = URL(string: "\(baseURL)/bikes/\(bikeId)")!
        
        return makeAuthenticatedRequest(url: url, method: "PUT", body: bike)
    }
    
    func deleteBike(bikeId: String) -> AnyPublisher<MessageResponse, Error> {
        let url = URL(string: "\(baseURL)/bikes/\(bikeId)")!
        
        return makeAuthenticatedRequest(url: url, method: "DELETE", body: EmptyBody())
    }
    
    // Friends' garage
    func getBikes(for userId: Int) -> AnyPublisher<[Bike], Error> {
        let url = URL(string: "\(baseURL)/users/\(userId)/bikes")!
        return makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
            .map { (response: BikesResponse) in response.bikes }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Admin APIs
    func fetchAdminUsers(search: String, page: Int = 1, limit: Int = 50, completion: @escaping (Result<[AdminUser], Error>) -> Void) {
        struct AdminUsersResponse: Codable { let users: [AdminUser] }
        var components = URLComponents(string: "\(baseURL)/admin/users")!
        components.queryItems = [
            URLQueryItem(name: "search", value: search),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        guard let url = components.url else { completion(.failure(URLError(.badURL))); return }
        
        makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
            .sink(receiveCompletion: { comp in
                if case let .failure(err) = comp { completion(.failure(err)) }
            }, receiveValue: { (resp: AdminUsersResponse) in
                completion(.success(resp.users))
            })
            .store(in: &cancellables)
    }
    
    func fetchAdminStats(completion: @escaping (Result<AdminStats, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/admin/stats") else { completion(.failure(URLError(.badURL))); return }
        makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
            .sink(receiveCompletion: { comp in
                if case let .failure(err) = comp { completion(.failure(err)) }
            }, receiveValue: { (stats: AdminStats) in
                completion(.success(stats))
            })
            .store(in: &cancellables)
    }
    
    func fetchAdminPosts(limit: Int = 50, offset: Int = 0, completion: @escaping (Result<[AdminPost], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/admin/table/posts?limit=\(limit)&offset=\(offset)") else { completion(.failure(URLError(.badURL))); return }
        makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
            .sink(receiveCompletion: { comp in
                if case let .failure(err) = comp { completion(.failure(err)) }
            }, receiveValue: { (resp: AdminTableResponse<AdminPost>) in
                completion(.success(resp.rows))
            })
            .store(in: &cancellables)
    }
    
    func fetchAdminRides(limit: Int = 50, offset: Int = 0, completion: @escaping (Result<[AdminRide], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/admin/table/rides?limit=\(limit)&offset=\(offset)") else { completion(.failure(URLError(.badURL))); return }
        makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
            .sink(receiveCompletion: { comp in
                if case let .failure(err) = comp { completion(.failure(err)) }
            }, receiveValue: { (resp: AdminTableResponse<AdminRide>) in
                completion(.success(resp.rows))
            })
            .store(in: &cancellables)
    }
    
    func updateUserRole(userId: Int, role: String, completion: @escaping (Result<Void, Error>) -> Void) {
        struct UpdateRoleRequest: Codable { let role: String }
        guard let url = URL(string: "\(baseURL)/admin/users/\(userId)/role") else { completion(.failure(URLError(.badURL))); return }
        let body = UpdateRoleRequest(role: role)
        makeAuthenticatedRequest(url: url, method: "PUT", body: body)
            .sink(receiveCompletion: { comp in
                switch comp {
                case .finished: completion(.success(()))
                case .failure(let err): completion(.failure(err))
                }
            }, receiveValue: { (_: MessageResponse) in })
            .store(in: &cancellables)
    }
    
    func updateUserSubscription(userId: Int, tier: String, completion: @escaping (Result<Void, Error>) -> Void) {
        struct UpdateTierRequest: Codable { let tier: String }
        guard let url = URL(string: "\(baseURL)/admin/users/\(userId)/subscription") else { completion(.failure(URLError(.badURL))); return }
        let body = UpdateTierRequest(tier: tier)
        makeAuthenticatedRequest(url: url, method: "PUT", body: body)
            .sink(receiveCompletion: { comp in
                switch comp {
                case .finished: completion(.success(()))
                case .failure(let err): completion(.failure(err))
                }
            }, receiveValue: { (_: MessageResponse) in })
            .store(in: &cancellables)
    }
    
    func fetchAdminHazards(limit: Int = 50, offset: Int = 0, completion: @escaping (Result<[AdminHazard], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/admin/table/hazard_reports?limit=\(limit)&offset=\(offset)") else { completion(.failure(URLError(.badURL))); return }
        makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
            .sink(receiveCompletion: { comp in if case let .failure(err) = comp { completion(.failure(err)) } }, receiveValue: { (resp: AdminTableResponse<AdminHazard>) in completion(.success(resp.rows)) })
            .store(in: &cancellables)
    }
    func fetchAdminEmergencies(limit: Int = 50, offset: Int = 0, completion: @escaping (Result<[AdminEmergency], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/admin/table/emergency_events?limit=\(limit)&offset=\(offset)") else { completion(.failure(URLError(.badURL))); return }
        makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
            .sink(receiveCompletion: { comp in if case let .failure(err) = comp { completion(.failure(err)) } }, receiveValue: { (resp: AdminTableResponse<AdminEmergency>) in completion(.success(resp.rows)) })
            .store(in: &cancellables)
    }
    func updateHazardStatus(hazardId: Int, status: String, completion: @escaping (Result<Void, Error>) -> Void) {
        struct Req: Codable { let status: String }
        guard let url = URL(string: "\(baseURL)/admin/hazards/\(hazardId)/status") else { completion(.failure(URLError(.badURL))); return }
        makeAuthenticatedRequest(url: url, method: "PUT", body: Req(status: status))
            .sink(receiveCompletion: { comp in switch comp { case .finished: completion(.success(())); case .failure(let e): completion(.failure(e)) } }, receiveValue: { (_: MessageResponse) in })
            .store(in: &cancellables)
    }
    func resolveEmergency(emergencyId: Int, resolved: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        struct Req: Codable { let resolved: Bool }
        guard let url = URL(string: "\(baseURL)/admin/emergencies/\(emergencyId)/resolve") else { completion(.failure(URLError(.badURL))); return }
        makeAuthenticatedRequest(url: url, method: "PUT", body: Req(resolved: resolved))
            .sink(receiveCompletion: { comp in switch comp { case .finished: completion(.success(())); case .failure(let e): completion(.failure(e)) } }, receiveValue: { (_: MessageResponse) in })
            .store(in: &cancellables)
    }
    
    // MARK: - Private Helper Methods
    
    private func makeRequest<T: Codable, U: Codable>(url: URL, method: String, body: T? = nil) -> AnyPublisher<U, Error> {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Only include body for non-GET requests
        if method != "GET", let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                return Fail(error: error).eraseToAnyPublisher()
            }
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                // Check HTTP status code
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                // Handle error status codes
                if httpResponse.statusCode >= 400 {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                        throw NetworkError.serverError(errorResponse.error)
                    } else {
                        throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                    }
                }
                
                return data
            }
            .decode(type: U.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    private func makeAuthenticatedRequest<T: Codable, U: Codable>(url: URL, method: String, body: T? = nil) -> AnyPublisher<U, Error> {
        guard let token = authToken else {
            return Fail(error: NetworkError.notAuthenticated).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Only include body for non-GET requests
        if method != "GET", let body = body {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                request.httpBody = try encoder.encode(body)
            } catch {
                return Fail(error: error).eraseToAnyPublisher()
            }
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                // Check HTTP status code
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                // Handle error status codes
                if httpResponse.statusCode >= 400 {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                        throw NetworkError.serverError(errorResponse.error)
                    } else {
                        throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                    }
                }
                
                return data
            }
            .decode(type: U.self, decoder: {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return decoder
            }())
            .catch { error -> AnyPublisher<U, Error> in
                // Add debug logging for JSON decoding errors
                if let decodingError = error as? DecodingError {
                    print("🔴 JSON Decoding Error: \(decodingError)")
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("   Missing key: \(key.stringValue)")
                        print("   Context: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("   Type mismatch for: \(type)")
                        print("   Context: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("   Value not found for: \(type)")
                        print("   Context: \(context.debugDescription)")
                    case .dataCorrupted(let context):
                        print("   Data corrupted: \(context.debugDescription)")
                    @unknown default:
                        print("   Unknown decoding error")
                    }
                }
                return Fail(error: error).eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    private func handleAuthSuccess(_ response: AuthResponse) {
        self.authToken = response.token
        
        // Convert BackendUser to User
        let user = User(
            id: UUID(), // Generate new UUID for app
            username: response.user?.username ?? "",
            email: response.user?.email ?? "",
            firstName: response.user?.firstName,
            lastName: response.user?.lastName,
            phone: response.user?.phone,
            bio: response.user?.bio ?? "",
            bike: "\(response.user?.motorcycleMake ?? "") \(response.user?.motorcycleModel ?? "")".trimmingCharacters(in: .whitespaces),
            motorcycleMake: response.user?.motorcycleMake,
            motorcycleModel: response.user?.motorcycleModel,
            motorcycleYear: response.user?.motorcycleYear,
            profilePictureUrl: response.user?.profilePictureUrl,
            ridingExperience: User.RidingExperience(rawValue: response.user?.ridingExperience ?? "beginner") ?? .beginner,
            stats: UserStats(),
            postsCount: response.user?.postsCount ?? 0,
            followersCount: response.user?.followersCount ?? 0,
            followingCount: response.user?.followingCount ?? 0,
            status: User.UserStatus(rawValue: response.user?.status ?? "offline") ?? .offline,
            locationSharingEnabled: response.user?.locationSharingEnabled ?? false,
            isVerified: response.user?.isVerified ?? false,
            followers: [],
            following: [],
            badges: [],
            rank: 999,
            joinDate: Date()
        )
        
        self.currentUser = user
        self.isLoggedIn = true
        
        // Store auth data
        UserDefaults.standard.set(response.token, forKey: "auth_token")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let userData = try? encoder.encode(user) {
            UserDefaults.standard.set(userData, forKey: "current_user")
        }
        
        print("✅ Authentication successful for user: \(user.username)")
    }
    
    private func handleLogout() {
        self.authToken = nil
        self.currentUser = nil
        self.isLoggedIn = false
        
        // Clear stored auth data
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "current_user")
    }
    
    private func loadStoredAuth() {
        if let token = UserDefaults.standard.string(forKey: "auth_token"),
           let userData = UserDefaults.standard.data(forKey: "current_user") {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let user = try? decoder.decode(User.self, from: userData) {
                self.authToken = token
                self.currentUser = user
                self.isLoggedIn = true
            }
        }
    }
    
    // MARK: - Development Helper Methods
    
    // (Removed autoLoginForDevelopment to ensure real authentication)
    
    // MARK: - Helper Methods
    
    static func createJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    static func createJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    // Push token registration
    func registerPushToken(_ token: String) -> AnyPublisher<MessageResponse, Error> {
        let url = URL(string: "\(baseURL)/users/push-token")!
        struct PushTokenReq: Codable { let token: String }
        return makeAuthenticatedRequest(url: url, method: "POST", body: PushTokenReq(token: token))
    }

    // Subscription verification (server)
    func verifyReceipt(productId: String, transactionId: String?, payload: String?) -> AnyPublisher<MessageResponse, Error> {
        let url = URL(string: "\(baseURL)/users/verify-receipt")!
        struct VerifyReq: Codable { let productId: String; let transactionId: String?; let payload: String? }
        return makeAuthenticatedRequest(url: url, method: "POST", body: VerifyReq(productId: productId, transactionId: transactionId, payload: payload))
    }
}

// MARK: - Request Models (unique to NetworkManager)

struct RegisterRequest: Codable {
    let username: String
    let email: String
    let password: String
    let firstName: String
    let lastName: String
    let phoneNumber: String?
    let motorcycleMake: String?
    let motorcycleModel: String?
    let motorcycleYear: String?
    let ridingExperience: String
}

struct StartRideRequest: Codable {
    let title: String?
    let startLocation: String?
    let plannedRoute: String?
}

struct LocationUpdateRequest: Codable {
    let latitude: Double
    let longitude: Double
    let speed: Double?
    let heading: Double?
    let accuracy: Double?
}

struct CompleteRideRequest: Codable {
    let endLocation: String?
    let distance: Double?
    let duration: Int?
    let averageSpeed: Double?
    let maxSpeed: Double?
    let safetyScore: Int?
}

struct EmergencyRequest: Codable {
    let type: String
    let severity: String
    let location: String
    let description: String?
    let automaticDetection: Bool
    let sensorData: String?
}

struct HazardRequest: Codable {
    let type: String
    let location: String
    let description: String?
    let severity: String?
    let images: [String]?
}

struct CreateRideRequest: Codable {
    let startTime: Date
    let endTime: Date
    let distance: Double
    let maxSpeed: Double
    let avgSpeed: Double
    let startLocation: String?
    let endLocation: String?
}

struct AddCommentRequest: Codable {
    let content: String
}

struct SharePostRequest: Codable {
    let caption: String?
}

// MARK: - Error Types

enum NetworkError: Error {
    case notAuthenticated
    case invalidResponse
    case serverError(String)
    case invalidURL
    case noData
}

extension NetworkError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return message
        case .invalidURL:
            return "The URL is invalid"
        case .noData:
            return "No data received from server"
        }
    }
} 

// MARK: - Additional API Data Models
struct CreateRideResponse: Codable {
    let success: Bool
    let message: String
    let ride: APIRide
}

struct APIRide: Codable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let distance: Double
    let avgSpeed: Double
    let maxSpeed: Double
    let startLocation: String?
    let endLocation: String?
    let safetyScore: Int?
}

// Note: NearbyRidersResponse, APINearbyRider, and EmptyBody are defined in DataModels.swift

struct DictionaryBody: Codable {
    let data: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case data
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data.mapValues { AnyCodable($0) })
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: AnyCodable].self)
        self.data = dict.mapValues { $0.value }
    }
    
    init(data: [String: Any]) {
        self.data = data
    }
}

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case is NSNull:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Cannot encode value"))
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
} 

// Note: ErrorResponse is defined in DataModels.swift

// MARK: - Public Ride APIs
extension NetworkManager {
    struct EndRideRequest: Codable {
        let endLocation: String?
        let totalDistance: Double
        let maxSpeed: Double
        let avgSpeed: Double
        let durationMinutes: Int
    }
    
    func endRide(rideId: Int, endLocation: String?, totalDistance: Double, maxSpeed: Double, avgSpeed: Double, durationMinutes: Int) -> AnyPublisher<MessageResponse, Error> {
        guard let token = authToken else {
            return Fail(error: NetworkError.notAuthenticated).eraseToAnyPublisher()
        }
        let url = URL(string: "\(baseURL)/rides/\(rideId)/end")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body = EndRideRequest(endLocation: endLocation, totalDistance: totalDistance, maxSpeed: maxSpeed, avgSpeed: avgSpeed, durationMinutes: durationMinutes)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                    throw NetworkError.invalidResponse
                }
                return data
            }
            .decode(type: MessageResponse.self, decoder: NetworkManager.createJSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

// MARK: - Admin Models
struct AdminStats: Codable {
    let users: Int?
    let posts: Int?
    let rides: Int?
    let emergency_events: Int?
    let hazard_reports: Int?
    let followers: Int?
    let post_likes: Int?
    let post_comments: Int?
    let location_updates: Int?
    let riding_packs: Int?
    let pack_members: Int?
    let user_sessions: Int?
    let story_views: Int?
    let stories: Int?
}

struct AdminTableResponse<Row: Codable>: Codable {
    let rows: [Row]
    let total: Int?
    let limit: Int?
    let offset: Int?
}

struct AdminPost: Codable, Identifiable {
    let id: Int
    let user_id: Int
    let content: String?
    let likes_count: Int?
    let comments_count: Int?
    let created_at: String?
}

struct AdminRide: Codable, Identifiable {
    let id: Int
    let user_id: Int
    let title: String?
    let total_distance: Double?
    let avg_speed: Double?
    let max_speed: Double?
    let status: String?
    let start_time: String?
}

struct AdminHazard: Codable, Identifiable { let id: Int; let reporter_id: Int?; let hazard_type: String?; let severity: String?; let latitude: Double?; let longitude: Double?; let location_name: String?; let description: String?; let status: String?; let created_at: String? }
struct AdminEmergency: Codable, Identifiable { let id: Int; let user_id: Int?; let ride_id: Int?; let event_type: String?; let severity: String?; let latitude: Double?; let longitude: Double?; let location_name: String?; let description: String?; let is_resolved: Int?; let created_at: String?; let resolved_at: String? }

// MARK: - Fuel Logs APIs
extension NetworkManager {
    func createFuelLog(_ requestBody: CreateFuelLogRequest) -> AnyPublisher<FuelLogResponse, Error> {
        let url = URL(string: "\(baseURL)/fuel")!
        return makeAuthenticatedRequest(url: url, method: "POST", body: requestBody)
    }
    
    func listFuelLogs(bikeId: String? = nil, limit: Int = 50, offset: Int = 0) -> AnyPublisher<FuelLogsResponse, Error> {
        var components = URLComponents(string: "\(baseURL)/fuel")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        if let bikeId = bikeId { queryItems.append(URLQueryItem(name: "bikeId", value: bikeId)) }
        components.queryItems = queryItems
        return makeAuthenticatedRequest(url: components.url!, method: "GET", body: EmptyBody())
    }
    
    func updateFuelLog(id: String, requestBody: CreateFuelLogRequest) -> AnyPublisher<FuelLogResponse, Error> {
        let url = URL(string: "\(baseURL)/fuel/\(id)")!
        return makeAuthenticatedRequest(url: url, method: "PUT", body: requestBody)
    }
    
    func deleteFuelLog(id: String) -> AnyPublisher<MessageResponse, Error> {
        let url = URL(string: "\(baseURL)/fuel/\(id)")!
        return makeAuthenticatedRequest(url: url, method: "DELETE", body: EmptyBody())
    }
}

// MARK: - Ride Recordings APIs
extension NetworkManager {
    func uploadRideRecording(_ requestBody: CreateRideRecordingRequest) -> AnyPublisher<RideRecordingResponse, Error> {
        let url = URL(string: "\(baseURL)/recordings")!
        return makeAuthenticatedRequest(url: url, method: "POST", body: requestBody)
    }
    
    func listRideRecordings(rideId: String? = nil, limit: Int = 20, offset: Int = 0) -> AnyPublisher<RideRecordingsResponse, Error> {
        var components = URLComponents(string: "\(baseURL)/recordings")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        if let rideId = rideId { queryItems.append(URLQueryItem(name: "rideId", value: rideId)) }
        components.queryItems = queryItems
        return makeAuthenticatedRequest(url: components.url!, method: "GET", body: EmptyBody())
    }
}

// MARK: - Events APIs  
extension NetworkManager {
    func getEvents() -> AnyPublisher<EventsResponse, Error> {
        let url = URL(string: "\(baseURL)/events")!
        return makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
    }
    
    func getCompletedRides() -> AnyPublisher<CompletedRidesResponse, Error> {
        let url = URL(string: "\(baseURL)/rides/completed")!
        return makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
    }
}

// MARK: - Safety APIs
extension NetworkManager {
    func reportEmergency(_ requestBody: EmergencyReportRequest) -> AnyPublisher<EmergencyReportResponse, Error> {
        let url = URL(string: "\(baseURL)/safety/emergency")!
        return makeAuthenticatedRequest(url: url, method: "POST", body: requestBody)
    }
}