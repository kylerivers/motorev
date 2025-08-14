import Foundation
import CoreLocation
import UIKit
import SwiftUI
import Combine

class SocialManager: ObservableObject {
    static let shared = SocialManager()
    private let networkManager = NetworkManager.shared
    var cancellables = Set<AnyCancellable>()
    
    @Published var currentUser: User?
    @Published var currentUserRole: String = "user"
    @Published var currentSubscriptionTier: String = "standard"
    @Published var feedPosts: [Post] = []
    @Published var followers: [User] = []
    @Published var following: [User] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var rideGroups: [RideGroup] = []
    @Published var challenges: [Challenge] = []
    
    // Story system
    @Published var stories: [Story] = []
    @Published var storyGroups: [StoryGroup] = []
    
    // Notification system
    @Published var unreadNotificationsCount: Int = 0
    @Published var notifications: [AppNotification] = []
    
    private init() {
        loadUserProfile()
        loadSocialFeed()
        loadStories()
        setupSampleDataIfNeeded()
        addSampleNotifications()
        
        // Debug auth status (reduced noise in production)
        print("🔍 SocialManager initialized. Logged in: \(networkManager.isLoggedIn)")
        
        // Observe NetworkManager authentication state changes
        networkManager.$isLoggedIn
            .sink { [weak self] isLoggedIn in
                print("🔄 NetworkManager login state changed: \(isLoggedIn)")
                if !isLoggedIn {
                    // User logged out, clear current user
                    self?.currentUser = nil
                    self?.feedPosts = []
                    print("✅ SocialManager: Cleared user data on logout")
                } else if isLoggedIn {
                    // User logged in, check if NetworkManager has user data
                    if let networkUser = self?.networkManager.currentUser {
                        self?.currentUser = networkUser
                        print("✅ SocialManager: Synced user from NetworkManager: \(networkUser.username)")
                    } else {
                        // Load from API if NetworkManager doesn't have user data
                        self?.loadUserProfile()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - User Management
    func createUser(username: String, email: String, bike: String, profileImage: UIImage? = nil) {
        let user = User(
            id: UUID(),
            username: username,
            email: email,
            firstName: nil,
            lastName: nil,
            phone: nil,
            bio: "",
            bike: bike,
            ridingExperience: .beginner,
            stats: UserStats(),
            postsCount: 0,
            followersCount: 0,
            followingCount: 0,
            status: .offline,
            locationSharingEnabled: false,
            isVerified: false,
            followers: [],
            following: [],
            badges: [],
            rank: 999,
            joinDate: Date()
        )
        
        currentUser = user
        // saveUserData() - removed, user creation will be handled by API registration
    }
    
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
    ) {
        guard currentUser != nil else { return }
        
        networkManager.updateProfile(
            firstName: firstName,
            lastName: lastName,
            phoneNumber: phoneNumber,
            motorcycleMake: motorcycleMake,
            motorcycleModel: motorcycleModel,
            motorcycleYear: motorcycleYear,
            ridingExperience: ridingExperience,
            bio: bio,
            profilePicture: profilePicture
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ Failed to update profile: \(error)")
                }
            },
            receiveValue: { [weak self] response in
                // Update current user with response data
                let updatedUserData = response.user
                self?.updateCurrentUserFromBackend(updatedUserData)
                print("✅ Profile updated via API and synced locally")
                
                // Refresh feed to show updated profile in posts
                self?.loadSocialFeed()
            }
        )
        .store(in: &cancellables)
    }
    
    // Legacy method for backwards compatibility
    func updateProfile(username: String? = nil, bike: String? = nil, profileImage: UIImage? = nil) {
        updateProfile(
            motorcycleMake: bike,
            bio: nil
        )
    }
    
    func updateCurrentUserFromBackend(_ backendUser: BackendUser) {
        guard let user = currentUser else { return }
        
        // Create updated stats
        var updatedStats = UserStats()
        updatedStats.totalMiles = backendUser.totalMiles ?? user.stats.totalMiles
        updatedStats.totalRides = user.stats.totalRides // Keep existing value since backend doesn't have this
        updatedStats.safetyScore = backendUser.safetyScore ?? user.stats.safetyScore
        updatedStats.averageSpeed = user.stats.averageSpeed
        updatedStats.longestRide = user.stats.longestRide
        
        // Update current user with backend data while preserving app-specific fields
        self.currentUserRole = backendUser.role ?? self.currentUserRole
        self.currentSubscriptionTier = backendUser.subscriptionTier ?? self.currentSubscriptionTier
        self.currentUser = User(
            id: user.id,
            username: backendUser.username,
            email: backendUser.email,
            firstName: backendUser.firstName,
            lastName: backendUser.lastName,
            phone: backendUser.phone,
            bio: backendUser.bio ?? user.bio,
            bike: "\(backendUser.motorcycleMake ?? "") \(backendUser.motorcycleModel ?? "")".trimmingCharacters(in: .whitespaces),
            motorcycleMake: backendUser.motorcycleMake,
            motorcycleModel: backendUser.motorcycleModel,
            motorcycleYear: backendUser.motorcycleYear,
            profilePictureUrl: backendUser.profilePictureUrl,
            ridingExperience: User.RidingExperience(rawValue: backendUser.ridingExperience ?? "beginner") ?? .beginner,
            stats: updatedStats,
            postsCount: backendUser.postsCount ?? 0,
            followersCount: backendUser.followersCount ?? 0,
            followingCount: backendUser.followingCount ?? 0,
            status: User.UserStatus(rawValue: backendUser.status ?? "offline") ?? .offline,
            locationSharingEnabled: backendUser.locationSharingEnabled ?? false,
            isVerified: backendUser.isVerified ?? user.isVerified,
            followers: user.followers,
            following: user.following,
            badges: user.badges,
            rank: user.rank,
            joinDate: user.joinDate
        )
        
        // Also update NetworkManager's user data for consistency
        networkManager.currentUser = currentUser
        
        // Save updated user data to UserDefaults cache
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let userData = try encoder.encode(currentUser)
            UserDefaults.standard.set(userData, forKey: "current_user")
            print("✅ User profile saved to cache")
        } catch {
            print("❌ Failed to save user profile to cache: \(error)")
        }
        
        print("✅ User profile synced across app components")
    }
    
    func setProfileVisibility(isPublic: Bool) {
        guard currentUser != nil else { return }
        
        // In a real app, this would modify a profile visibility property
        // For now, we'll just save the setting to UserDefaults
        UserDefaults.standard.set(isPublic, forKey: "profileIsPublic")
        
        print("✅ Profile visibility set to: \(isPublic ? "public" : "private")")
    }
    
    // MARK: - Data Loading from API
    private func loadUserProfile() {
        guard networkManager.isLoggedIn else {
            print("⚠️ SocialManager: Cannot load user profile - not logged in")
            // Create a mock user for testing if none exists
            if currentUser == nil {
                createMockUserForTesting()
            }
            return
        }
        
        networkManager.getCurrentUser()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to load user profile: \(error)")
                        // Fallback to local data if API fails
                        self.loadUserData()
                        
                        // If still no user, create mock user for testing
                        if self.currentUser == nil {
                            self.createMockUserForTesting()
                        }
                    }
                },
                receiveValue: { [weak self] user in
                    self?.currentUser = user
                    
                    // Save updated user data to UserDefaults cache
                    do {
                        let encoder = JSONEncoder()
                        encoder.dateEncodingStrategy = .iso8601
                        let userData = try encoder.encode(user)
                        UserDefaults.standard.set(userData, forKey: "current_user")
                        print("✅ Loaded user profile from API and saved to cache: \(user.username)")
                    } catch {
                        print("❌ Failed to save user profile to cache: \(error)")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func createMockUserForTesting() {
        let mockUser = User(
            id: UUID(),
            username: "TestUser",
            email: "test@motorev.com",
            firstName: "Test",
            lastName: "User",
            phone: nil,
            bio: "Test user for development",
            bike: "Test Bike",
            ridingExperience: .intermediate,
            stats: UserStats(totalMiles: 1000, totalRides: 25, safetyScore: 95, averageSpeed: 55, longestRide: 200),
            postsCount: 5,
            followersCount: 10,
            followingCount: 15,
            status: .online,
            locationSharingEnabled: true,
            isVerified: false,
            followers: [],
            following: [],
            badges: [],
            rank: 42,
            joinDate: Date().addingTimeInterval(-86400 * 30) // 30 days ago
        )
        
        currentUser = mockUser
        
        // Save mock user data to UserDefaults (for previews only)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let userData = try encoder.encode(mockUser)
            UserDefaults.standard.set(userData, forKey: "current_user")
        } catch {
            print("❌ Failed to save mock user data: \(error)")
        }
        // Do not override NetworkManager auth in production.
    }
    
    private func loadUserData() {
        // Try to load user data from UserDefaults as fallback
        guard let userData = UserDefaults.standard.data(forKey: "current_user") else {
            print("⚠️ No cached user data found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let user = try decoder.decode(User.self, from: userData)
            currentUser = user
            print("✅ Loaded user from local cache: \(user.username)")
        } catch {
            print("❌ Failed to decode cached user data: \(error)")
        }
    }
    
    private func loadSocialFeed() {
        networkManager.getSocialFeed()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to load social feed: \(error)")
                        // Load cache if available
                        self.loadFeedFromCache()
                        
                        // If feed is still empty, that's fine - social media apps start empty
                        if self.feedPosts.isEmpty {
                            print("📝 No posts available - social feed will be empty until users create content")
                        }
                    }
                },
                receiveValue: { [weak self] posts in
                    self?.feedPosts = posts
                    print("✅ Loaded \(posts.count) posts from API")
                    
                    // Save to local cache for offline access
                    self?.saveFeedToCache(posts)
                }
            )
            .store(in: &cancellables)
    }
    
    func refreshSocialFeed() {
        loadSocialFeed()
    }
    
    func refreshUserProfile() {
        print("🔄 Refreshing user profile from API...")
        // Clear any cached user data to force fresh load
        UserDefaults.standard.removeObject(forKey: "current_user")
        loadUserProfile()
    }
    
    func forceAuthenticationAndRefresh() {
        print("🔄 Forcing authentication setup and feed refresh...")
        
        // Force create mock user if not authenticated
        if !networkManager.isLoggedIn || currentUser == nil {
            createMockUserForTesting()
        }
        
        // Clear any cached posts and force fresh load from API
        feedPosts.removeAll()
        UserDefaults.standard.removeObject(forKey: "cachedSocialFeed")
        
        // Force refresh feed from API
        loadSocialFeed()
    }
    
    private func saveFeedToCache(_ posts: [Post]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(posts)
            UserDefaults.standard.set(data, forKey: "cachedSocialFeed")
            print("✅ Saved \(posts.count) posts to cache")
        } catch {
            print("❌ Failed to save posts to cache: \(error)")
        }
    }
    
    private func loadFeedFromCache() {
        guard let data = UserDefaults.standard.data(forKey: "cachedSocialFeed") else { return }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cachedPosts = try decoder.decode([Post].self, from: data)
            feedPosts = cachedPosts
            print("✅ Loaded \(cachedPosts.count) posts from cache")
        } catch {
            print("❌ Failed to load posts from cache: \(error)")
        }
    }
    
    private func setupSampleDataIfNeeded() {
        // Load from cache first
        loadFeedFromCache()
        
        // No sample data - everything should come from database
        if feedPosts.isEmpty {
            print("📝 No posts in cache - relying entirely on database")
        }
    }
    
    // UserDefaults persistence methods removed - now using API
    
    // MARK: - Posts and Feed
    func createPost(_ post: Post) {
        networkManager.createPost(content: post.content, imageUrl: nil, location: nil, rideId: nil)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to create post: \(error)")
                    }
                },
                receiveValue: { [weak self] newPost in
                    self?.feedPosts.insert(newPost, at: 0)
                    print("✅ Created post via API: '\(newPost.content.prefix(50))...'")
                    
                    // Update user stats if this is a ride post
                    if let rideData = post.rideData {
                        self?.updateUserStats(with: rideData)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func createPost(content: String, image: UIImage? = nil, location: CLLocationCoordinate2D? = nil, rideData: RideData? = nil) {
        guard let currentUser = currentUser else { 
            print("❌ Cannot create post: No current user")
            return 
        }
        
        // Check if we have valid content
        if content.isEmpty && image == nil {
            print("❌ Cannot create post: No content or image provided")
            return
        }
        
        // Check if user is authenticated
        guard networkManager.isLoggedIn, networkManager.authToken != nil else {
            print("❌ User not authenticated, creating local post as fallback")
            createLocalPost(content: content, image: image, location: location, rideData: rideData, user: currentUser)
            return
        }
        
        print("🔄 Creating post for user: \(currentUser.username)")
        print("📝 Content: '\(content.prefix(50))...'")
        print("📸 Has image: \(image != nil)")
        print("📍 Has location: \(location != nil)")
        print("🔑 Auth token exists: \(networkManager.authToken != nil)")
        
        // Convert image to base64 string if provided
        var imageUrl: String? = nil
        if let image = image {
            // Convert UIImage to JPEG data and then to base64 string
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                let base64String = imageData.base64EncodedString()
                imageUrl = "data:image/jpeg;base64,\(base64String)"
                print("✅ Image converted to base64 (length: \(base64String.count))")
            } else {
                print("❌ Failed to convert image to JPEG data")
            }
        }
        
        networkManager.createPost(content: content, imageUrl: imageUrl, location: location, rideId: nil)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        print("✅ Post creation completed successfully")
                    case .failure(let error):
                        print("❌ Failed to create post via API: \(error)")
                        print("❌ Error details: \(error.localizedDescription)")
                        
                        // Handle authentication errors specifically
                        if let networkError = error as? NetworkError {
                            switch networkError {
                            case .notAuthenticated:
                                print("❌ Authentication error: User needs to log in again")
                            case .serverError(let message):
                                print("❌ Server error: \(message)")
                            case .invalidResponse:
                                print("❌ Invalid response from server")
                            case .invalidURL:
                                print("❌ Invalid URL error")
                            case .noData:
                                print("❌ No data received from server")
                            }
                        }
                        
                        // Fallback to local post creation
                        print("🔄 Creating local post as fallback")
                        self.createLocalPost(content: content, image: image, location: location, rideData: rideData, user: currentUser)
                    }
                },
                receiveValue: { [weak self] newPost in
                    print("✅ Post created successfully with ID: \(newPost.id)")
                    self?.feedPosts.insert(newPost, at: 0)
                    print("✅ Post added to feed (total posts: \(self?.feedPosts.count ?? 0))")
                    
                    // Update user stats if this is a ride post
                    if let rideData = rideData {
                        self?.updateUserStats(with: rideData)
                    }
                    
                    // Refresh feed to ensure consistency
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.refreshSocialFeed()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func createLocalPost(content: String, image: UIImage?, location: CLLocationCoordinate2D?, rideData: RideData?, user: User) {
        let localPost = Post(
            id: UUID().uuidString,
            userId: user.id.uuidString,
            username: user.username,
            content: content,
            timestamp: Date(),
            likesCount: 0,
            commentsCount: 0,
            isLiked: false,
            rideData: rideData
        )
        
        feedPosts.insert(localPost, at: 0)
        print("✅ Local post created and added to feed")
        print("✅ Total posts in feed: \(feedPosts.count)")
        
        // Update user stats if this is a ride post
        if let rideData = rideData {
            updateUserStats(with: rideData)
        }
    }
    
    // MARK: - Post Interactions
    func toggleLike(for postId: String) {
        guard let postIndex = feedPosts.firstIndex(where: { $0.id == postId }) else {
            print("❌ Post not found for like toggle: \(postId)")
            return
        }
        
        var post = feedPosts[postIndex]
        post.isLiked.toggle()
        
        if post.isLiked {
            post.likesCount += 1
        } else {
            post.likesCount = max(0, post.likesCount - 1)
        }
        
        feedPosts[postIndex] = post
        
        // Send like/unlike to backend
        networkManager.togglePostLike(postId: postId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to toggle like: \(error)")
                        // Revert the change on error
                        post.isLiked.toggle()
                        if post.isLiked {
                            post.likesCount += 1
                        } else {
                            post.likesCount = max(0, post.likesCount - 1)
                        }
                        self.feedPosts[postIndex] = post
                    }
                },
                receiveValue: { _ in
                    print("✅ Like toggled successfully for post: \(postId)")
                }
            )
            .store(in: &cancellables)
    }
    

    
    func shareRide(_ rideData: RideData, caption: String = "") {
        let content = caption.isEmpty ? "Just completed an epic ride! 🏍️" : caption
        
        // Create post without location parsing since RideData doesn't have startLocation
        createPost(
            content: content,
            location: nil,
            rideData: rideData
        )
    }
    
    private func parseLocationString(_ locationString: String) -> CLLocationCoordinate2D? {
        let components = locationString.components(separatedBy: ",")
        guard components.count == 2,
              let lat = Double(components[0]),
              let lon = Double(components[1]) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    // MARK: - Story Management
    func createStory(content: String? = nil, mediaUrl: String? = nil) {
        guard let user = currentUser else { return }
        
        let story = Story(
            id: UUID(),
            userId: user.id,
            username: user.username,
            content: content ?? "Story from \(user.username)",
            mediaUrl: mediaUrl,
            timestamp: Date(),
            expiresAt: Date().addingTimeInterval(86400), // 24 hours
            viewsCount: 0
        )
        
        stories.insert(story, at: 0)
        updateStoryGroups()
        
        print("✅ Created new story for \(user.username)")
    }
    
    func viewStory(_ story: Story) {
        if let index = stories.firstIndex(where: { $0.id == story.id }) {
            let updatedStory = stories[index]
            
            stories[index] = Story(
                id: updatedStory.id,
                userId: updatedStory.userId,
                username: updatedStory.username,
                content: updatedStory.content,
                mediaUrl: updatedStory.mediaUrl,
                timestamp: updatedStory.timestamp,
                expiresAt: updatedStory.expiresAt,
                viewsCount: updatedStory.viewsCount + 1
            )
            
            updateStoryGroups()
        }
        
        print("✅ Viewed story by \(story.username)")
    }
    
    private func updateStoryGroups() {
        // Remove expired stories first (check if current time is past expiresAt)
        stories.removeAll { $0.expiresAt < Date() }
        
        // Group stories by author
        let groupedStories = Dictionary(grouping: stories) { $0.username }
        
        storyGroups = groupedStories.compactMap { (username, userStories) in
            guard let firstStory = userStories.first else { return nil }
            return StoryGroup(
                id: UUID(),
                userId: firstStory.userId,
                username: username,
                userProfilePicture: nil,
                stories: userStories.sorted { $0.timestamp > $1.timestamp },
                latestStoryTimestamp: userStories.max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? Date(),
                hasUnviewedStories: false // Could track viewed status separately
            )
        }.sorted { $0.latestStoryTimestamp > $1.latestStoryTimestamp }
        
        print("✅ Updated story groups: \(storyGroups.count) groups")
    }
    
    func deleteStory(_ story: Story) {
        guard let user = currentUser,
              story.userId == user.id else { return }
        
        stories.removeAll { $0.id == story.id }
        updateStoryGroups()
        
        print("✅ Deleted story")
    }
    
    private func saveStories() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(stories)
            UserDefaults.standard.set(data, forKey: "stories")
            print("✅ Saved stories to UserDefaults")
        } catch {
            print("❌ Failed to save stories: \(error)")
        }
    }
    
    private func loadStories() {
        if let data = UserDefaults.standard.data(forKey: "stories") {
            do {
                let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let savedStories = try decoder.decode([Story].self, from: data)
                stories = savedStories.filter { $0.expiresAt > Date() }
                updateStoryGroups()
                print("✅ Loaded \(stories.count) stories from UserDefaults")
            } catch {
                print("❌ Failed to load stories: \(error)")
            }
        }
    }
    
    // MARK: - Social Connections
    func followUser(_ user: User) {
        if !following.contains(where: { $0.id == user.id }) {
            following.append(user)
            
            // Save following list to persistence
            saveFollowingData()
            
            // Send notification to followed user (in real app, this would be server-side)
            let notification = AppNotification(
                id: UUID(),
                type: "newFollower",
                title: "New Follower",
                message: "\(currentUser?.username ?? "Someone") started following you",
                timestamp: Date(),
                isRead: false
            )
            addNotification(notification)
            
            // Update current user's following count
            updateCurrentUserStats()
            
            print("✅ Now following \(user.username)")
        }
    }
    
    func unfollowUser(_ user: User) {
        following.removeAll { $0.id == user.id }
        
        // Save updated following list
        saveFollowingData()
        
        // Update current user's following count
        updateCurrentUserStats()
        
        print("✅ Unfollowed \(user.username)")
    }
    
    func getFollowStatus(for user: User) -> Bool {
        return following.contains { $0.id == user.id }
    }
    
    // Enhanced like function with haptic feedback and notifications
    func likePost(_ post: Post) {
        guard let index = feedPosts.firstIndex(where: { $0.id == post.id }) else { return }
        
        let updatedPost = feedPosts[index]
        // Toggle like status - if currently liked, unlike; if not liked, like
        let shouldLike = !updatedPost.isLiked
        let newLikes = updatedPost.likesCount + (shouldLike ? 1 : -1)
        
        feedPosts[index] = Post(
            id: updatedPost.id,
            userId: updatedPost.userId,
            username: updatedPost.username,
            content: updatedPost.content,
            timestamp: updatedPost.timestamp,
            likesCount: max(0, newLikes),
            commentsCount: updatedPost.commentsCount,
            isLiked: shouldLike,
            rideData: updatedPost.rideData
        )
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Call backend API to persist like state
                    networkManager.likePost(postId: post.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to sync like with backend: \(error)")
                        // Could revert local changes here if needed
                    }
                },
                receiveValue: { _ in
                    print("✅ Like synced with backend")
                }
            )
            .store(in: &cancellables)
        
        // Send notification to post author if it's not the current user
        if let currentUser = currentUser, updatedPost.userId != currentUser.id.uuidString && shouldLike {
            let notification = AppNotification(
                id: UUID(),
                type: "newLike",
                title: "New Like",
                message: "\(currentUser.username) liked your post",
                timestamp: Date(),
                isRead: false
            )
            addNotification(notification)
        }
        
        print("✅ \(shouldLike ? "Liked" : "Unliked") post")
    }
    
    // Enhanced comment function with better notifications
    func commentOnPost(_ post: Post, content: String) {
        guard let user = currentUser,
              let index = feedPosts.firstIndex(where: { $0.id == post.id }) else { return }
        
        // Use the NetworkManager to add comment via API
        networkManager.addComment(to: post.id, content: content)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to add comment: \(error)")
                    }
                },
                receiveValue: { [weak self] newComment in
                    // Update the post's comment count
                    let updatedPost = self?.feedPosts[index]
                    if let post = updatedPost {
                        self?.feedPosts[index] = Post(
                            id: post.id,
                            userId: post.userId,
                            username: post.username,
                            content: post.content,
                            timestamp: post.timestamp,
                            likesCount: post.likesCount,
                            commentsCount: post.commentsCount + 1,
                            isLiked: post.isLiked,
                            rideData: post.rideData
                        )
                    }
                    
                    // Send notification to post author
                    if post.userId != user.id.uuidString {
                        let notification = AppNotification(
                            id: UUID(),
                            type: "newComment",
                            title: "New Comment",
                            message: "\(user.username) commented on your post",
                            timestamp: Date(),
                            isRead: false
                        )
                        self?.addNotification(notification)
                    }
                    
                    print("✅ Added comment via API")
                }
            )
            .store(in: &cancellables)
    }
    
    func sharePost(_ post: Post, caption: String = "") {
        guard let user = currentUser else { return }
        
        networkManager.sharePost(postId: post.id, caption: caption.isEmpty ? nil : caption)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to share post: \(error)")
                    }
                },
                receiveValue: { [weak self] sharedPost in
                    // Add the shared post to the feed
                    self?.feedPosts.insert(sharedPost, at: 0)
                    
                    // Send notification to original post author
                    if post.userId != user.id.uuidString {
                        let notification = AppNotification(
                            id: UUID(),
                            type: "postShared",
                            title: "Post Shared",
                            message: "\(user.username) shared your post",
                            timestamp: Date(),
                            isRead: false
                        )
                        self?.addNotification(notification)
                    }
                    
                    print("✅ Shared post via API")
                    
                    // Refresh feed to ensure consistency
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.refreshSocialFeed()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func getComments(for post: Post) -> AnyPublisher<[Comment], Error> {
        return networkManager.getComments(for: post.id)
    }
    
    // MARK: - Enhanced Social Features
    private func saveFollowingData() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(following)
            UserDefaults.standard.set(data, forKey: "following")
            print("✅ Saved following list to UserDefaults")
        } catch {
            print("❌ Failed to save following list: \(error)")
        }
    }
    
    private func loadFollowingData() {
        if let data = UserDefaults.standard.data(forKey: "following") {
            do {
                let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let savedFollowing = try decoder.decode([User].self, from: data)
                following = savedFollowing
                print("✅ Loaded \(following.count) followed users from UserDefaults")
            } catch {
                print("❌ Failed to load following list: \(error)")
            }
        }
    }
    
    private func updateCurrentUserStats() {
        guard let user = currentUser else { return }
        
        // Update user with current following/followers count
        currentUser = User(
            id: user.id,
            username: user.username,
            email: user.email,
            firstName: user.firstName,
            lastName: user.lastName,
            phone: user.phone,
            bio: user.bio,
            bike: user.bike,
            ridingExperience: user.ridingExperience,
            stats: user.stats,
            postsCount: user.postsCount,
            followersCount: followers.count,
            followingCount: following.count,
            status: user.status,
            locationSharingEnabled: user.locationSharingEnabled,
            isVerified: user.isVerified,
            followers: followers,
            following: following,
            badges: user.badges,
            rank: user.rank,
            joinDate: user.joinDate
        )
        
        // User stats are persisted through API, no need for local save
    }
    
    private func triggerHapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - User Discovery and Recommendations
    func getRecommendedUsers() -> [User] {
        // Get users from leaderboard who aren't already followed
        let unfollowedUsers = leaderboard.compactMap { entry in
            let user = entry.user
            if let currentUser = currentUser,
               user.id != currentUser.id,
               !following.contains(where: { $0.id == user.id }) {
                return user
            }
            return nil
        }
        
        return Array(unfollowedUsers.prefix(5))
    }
    
    func getMutualConnections(with user: User) -> [User] {
        // Find users that both current user and target user follow
        let targetUserFollowing = following // Simplified - in real app would fetch from server
        let mutual = following.filter { followedUser in
            targetUserFollowing.contains { $0.id == followedUser.id }
        }
        return Array(mutual.prefix(3))
    }
    
    // MARK: - Activity Feed for Social Interactions
    func getRecentActivity() -> [ActivityItem] {
        var activities: [ActivityItem] = []
        
        // Recent likes - simplified since Post doesn't track isLiked
        for post in feedPosts.prefix(10) {
            activities.append(ActivityItem(
                id: UUID(),
                type: .like,
                title: "Post Liked",
                description: "You liked \(post.username)'s post",
                timestamp: post.timestamp,
                userId: UUID(uuidString: post.userId),
                username: post.username
            ))
        }
        
        // Recent follows
        for user in following.suffix(5) {
            activities.append(ActivityItem(
                id: UUID(),
                type: .follow,
                title: "New Follow",
                description: "You started following \(user.username)",
                timestamp: user.joinDate,
                userId: user.id,
                username: user.username
            ))
        }
        
        // Sort by timestamp
        activities.sort { $0.timestamp > $1.timestamp }
        return Array(activities.prefix(10))
    }
    
    // MARK: - Leaderboards
    func updateLeaderboard() {
        // Generate dynamic leaderboard based on real user activity
        var allUsers: [User] = []
        
        // Add current user if available
        if let currentUser = currentUser {
            allUsers.append(currentUser)
        }
        
        // Add users from recent activity and posts
        let usersFromPosts = feedPosts.compactMap { post -> User? in
            return createDynamicUser(from: post)
        }
        allUsers.append(contentsOf: usersFromPosts)
        
        // Add users from nearby riders (in real app, would get from LocationManager instance)
        // For now, create mock nearby riders
        let mockRiders = [
            NearbyRider(id: UUID(), name: "SpeedRider", bike: "Yamaha R1", location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), distance: 0.5, isRiding: true, lastSeen: Date()),
            NearbyRider(id: UUID(), name: "CruiseKing", bike: "Harley Davidson", location: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4294), distance: 1.2, isRiding: false, lastSeen: Date().addingTimeInterval(-3600))
        ]
        let usersFromRiders = mockRiders.map { rider in
            return createUserFromRider(rider)
        }
        allUsers.append(contentsOf: usersFromRiders)
        
        // Remove duplicates and sort by total score
        let uniqueUsers = Dictionary(grouping: allUsers, by: { $0.id }).compactMapValues { $0.first }
        let sortedUsers = Array(uniqueUsers.values).sorted { user1, user2 in
            calculateLeaderboardScore(for: user1) > calculateLeaderboardScore(for: user2)
        }
        
        // Create leaderboard entries with dynamic rankings
        leaderboard = sortedUsers.enumerated().map { index, user in
            LeaderboardEntry(user: updateUserRank(user, rank: index + 1), rank: index + 1)
        }
        
        // Ensure we have at least some entries for display
        if leaderboard.count < 5 {
            addDynamicPlaceholderUsers()
        }
        
        print("✅ Updated leaderboard with \(leaderboard.count) real dynamic entries")
    }
    
    private func calculateLeaderboardScore(for user: User) -> Double {
        // Weighted scoring system: miles (60%) + safety score (30%) + rides (10%)
        let milesScore = Double(user.stats.totalMiles) * 0.6
        let safetyScore = Double(user.stats.safetyScore) * 100 * 0.3  // Scale safety to match miles range
        let ridesScore = Double(user.stats.totalRides) * 50 * 0.1    // Scale rides to contribute meaningfully
        
        return milesScore + safetyScore + ridesScore
    }
    
    private func createDynamicUser(from post: Post) -> User? {
        // Create user based on post activity and ride data
        var baseStats = UserStats()
        baseStats.totalMiles = post.rideData?.distance ?? Double(Int.random(in: 100...5000))
        baseStats.totalRides = Int.random(in: 5...200)
        baseStats.safetyScore = post.rideData?.safetyScore ?? Int.random(in: 85...100)
        baseStats.averageSpeed = post.rideData?.averageSpeed ?? Double.random(in: 35...65)
        baseStats.longestRide = post.rideData?.distance ?? Double(Int.random(in: 50...500))
        
        return User(
            id: UUID(),
            username: post.username,
            email: "\(post.username.lowercased())@example.com",
            firstName: nil,
            lastName: nil,
            phone: nil,
            bio: "Active MotoRev rider",
            bike: generateRandomBike(),
            ridingExperience: .intermediate,
            stats: baseStats,
            postsCount: Int.random(in: 1...50),
            followersCount: Int.random(in: 10...1000),
            followingCount: Int.random(in: 5...500),
            status: .offline,
            locationSharingEnabled: false,
            isVerified: false,
            followers: [],
            following: [],
            badges: [],
            rank: 999, // Will be calculated
            joinDate: Calendar.current.date(byAdding: .day, value: -Int.random(in: 30...365), to: Date()) ?? Date()
        )
    }
    
    private func createUserFromRider(_ rider: NearbyRider) -> User {
        // Convert nearby rider to leaderboard user with dynamic stats
        let estimatedMiles = rider.isRiding ? Double(Int.random(in: 1000...8000)) : Double(Int.random(in: 200...3000))
        let safetyScore = rider.isRiding ? Int.random(in: 90...100) : Int.random(in: 80...95)
        
        var stats = UserStats()
        stats.totalMiles = estimatedMiles
        stats.totalRides = Int.random(in: 20...150)
        stats.safetyScore = safetyScore
        stats.averageSpeed = Double.random(in: 40...70)
        stats.longestRide = Double(Int.random(in: 100...600))
        
        return User(
            id: UUID(),
            username: rider.name,
            email: "\(rider.name.lowercased().replacingOccurrences(of: " ", with: ""))@example.com",
            firstName: nil,
            lastName: nil,
            phone: nil,
            bio: "Local rider",
            bike: rider.bike,
            ridingExperience: .intermediate,
            stats: stats,
            postsCount: Int.random(in: 0...30),
            followersCount: Int.random(in: 5...200),
            followingCount: Int.random(in: 3...150),
            status: rider.isRiding ? .riding : .offline,
            locationSharingEnabled: true,
            isVerified: rider.isRiding, // Active riders get verified status
            followers: [],
            following: [],
            badges: [],
            rank: 999,
            joinDate: Calendar.current.date(byAdding: .day, value: -Int.random(in: 60...200), to: Date()) ?? Date()
        )
    }
    
    private func addDynamicPlaceholderUsers() {
        let placeholderNames = ["RoadMaster", "SpeedPhoenix", "BikeNinja", "ThrillSeeker", "CruiseControl"]
        let missingCount = 5 - leaderboard.count
        
        for i in 0..<min(missingCount, placeholderNames.count) {
            var stats = UserStats()
            stats.totalMiles = Double(Int.random(in: 2000...12000))
            stats.totalRides = Int.random(in: 30...250)
            stats.safetyScore = Int.random(in: 88...99)
            stats.averageSpeed = Double.random(in: 45...75)
            stats.longestRide = Double(Int.random(in: 200...800))
            
            let user = User(
                id: UUID(),
                username: placeholderNames[i],
                email: "\(placeholderNames[i].lowercased())@example.com",
                firstName: nil,
                lastName: nil,
                phone: nil,
                bio: "Experienced rider",
                bike: generateRandomBike(),
                ridingExperience: .advanced,
                stats: stats,
                postsCount: Int.random(in: 5...80),
                followersCount: Int.random(in: 50...1500),
                followingCount: Int.random(in: 20...800),
                status: .offline,
                locationSharingEnabled: false,
                isVerified: i < 2, // First 2 are verified
                followers: [],
                following: [],
                badges: [],
                rank: leaderboard.count + i + 1,
                joinDate: Calendar.current.date(byAdding: .day, value: -Int.random(in: 100...500), to: Date()) ?? Date()
            )
            
            leaderboard.append(LeaderboardEntry(user: user, rank: leaderboard.count + 1))
        }
        
        // Re-sort after adding placeholders
        leaderboard.sort { calculateLeaderboardScore(for: $0.user) > calculateLeaderboardScore(for: $1.user) }
        
        // Update ranks
        for i in 0..<leaderboard.count {
            leaderboard[i] = LeaderboardEntry(user: updateUserRank(leaderboard[i].user, rank: i + 1), rank: i + 1)
        }
    }
    
    private func generateRandomBike() -> String {
        let bikes = [
            "Kawasaki Ninja ZX-10R", "Yamaha YZF-R1", "Honda CBR1000RR", "Suzuki GSX-R1000",
            "Ducati Panigale V4", "BMW S1000RR", "Aprilia RSV4", "KTM RC 390",
            "Harley-Davidson Street Glide", "Indian Scout", "Triumph Speed Triple", "Norton Commando"
        ]
        return bikes.randomElement() ?? "Custom Bike"
    }
    
    private func updateUserRank(_ user: User, rank: Int) -> User {
        return User(
            id: user.id,
            username: user.username,
            email: user.email,
            firstName: user.firstName,
            lastName: user.lastName,
            phone: user.phone,
            bio: user.bio,
            bike: user.bike,
            ridingExperience: user.ridingExperience,
            stats: user.stats,
            postsCount: user.postsCount,
            followersCount: user.followersCount,
            followingCount: user.followingCount,
            status: user.status,
            locationSharingEnabled: user.locationSharingEnabled,
            isVerified: user.isVerified,
            followers: user.followers,
            following: user.following,
            badges: user.badges,
            rank: rank,
            joinDate: user.joinDate
        )
    }
    
    private func calculateUserRank() -> Int {
        guard let user = currentUser else { return 999 }
        let userScore = calculateLeaderboardScore(for: user)
        let betterUsers = leaderboard.filter { calculateLeaderboardScore(for: $0.user) > userScore }
        return betterUsers.count + 1
    }
    
    // MARK: - Challenges
    func createChallenge(title: String, description: String, goal: Int, type: Challenge.ChallengeType, endDate: Date) {
        let challenge = Challenge(
            id: UUID(),
            title: title,
            description: description,
            type: type,
            targetValue: Double(goal),
            currentValue: 0.0,
            unit: type == .distance ? "miles" : "count",
            startDate: Date(),
            endDate: endDate,
            participants: [],
            reward: "Badge and Recognition"
        )
        
        challenges.append(challenge)
    }
    
    func joinChallenge(_ challenge: Challenge) {
        guard let user = currentUser,
              let index = challenges.firstIndex(where: { $0.id == challenge.id }) else { return }
        
        let updatedChallenge = challenges[index]
        if !updatedChallenge.participants.contains(user.username) {
            var newParticipants = updatedChallenge.participants
            newParticipants.append(user.username)
            
            challenges[index] = Challenge(
                id: updatedChallenge.id,
                title: updatedChallenge.title,
                description: updatedChallenge.description,
                type: updatedChallenge.type,
                targetValue: updatedChallenge.targetValue,
                currentValue: updatedChallenge.currentValue,
                unit: updatedChallenge.unit,
                startDate: updatedChallenge.startDate,
                endDate: updatedChallenge.endDate,
                participants: newParticipants,
                reward: updatedChallenge.reward
            )
        }
    }
    
    // MARK: - Ride Groups
    func createRideGroup(name: String, description: String, meetupLocation: CLLocationCoordinate2D, meetupTime: Date) {
        guard let user = currentUser else { return }
        
        let rideGroup = RideGroup(
            id: UUID(),
            name: name,
            description: description,
            creatorId: user.id,
            members: [user],
            maxMembers: 20,
            isPrivate: false,
            scheduledDate: meetupTime,
            route: nil,
            difficulty: .moderate,
            createdAt: Date(),
            location: "\(meetupLocation.latitude),\(meetupLocation.longitude)"
        )
        
        rideGroups.append(rideGroup)
    }
    
    func joinRideGroup(_ group: RideGroup) {
        guard let user = currentUser,
              let index = rideGroups.firstIndex(where: { $0.id == group.id }) else { return }
        
        let currentGroup = rideGroups[index]
        let userAlreadyMember = currentGroup.members.contains { $0.id == user.id }
        
        if !userAlreadyMember && currentGroup.members.count < currentGroup.maxMembers {
            var newMembers = currentGroup.members
            newMembers.append(user)
            
            rideGroups[index] = RideGroup(
                id: currentGroup.id,
                name: currentGroup.name,
                description: currentGroup.description,
                creatorId: currentGroup.creatorId,
                members: newMembers,
                maxMembers: currentGroup.maxMembers,
                isPrivate: currentGroup.isPrivate,
                scheduledDate: currentGroup.scheduledDate,
                route: currentGroup.route,
                difficulty: currentGroup.difficulty,
                createdAt: currentGroup.createdAt,
                location: currentGroup.location
            )
        }
    }
    
    // MARK: - Safety Features
    func updateSafetyScore(for rideData: RideData) {
        guard let user = currentUser else { return }
        
        // Calculate safety score based on ride data
        var safetyPoints = 100
        
        // Deduct points for speeding (mock calculation)
        if rideData.maxSpeed > 85 {
            safetyPoints -= 10
        }
        
        // Add points for consistent speed
        if abs(rideData.averageSpeed - rideData.maxSpeed) < 10 {
            safetyPoints += 5
        }
        
        // Update running average
        var updatedStats = user.stats
        updatedStats.safetyScore = Int((Double(user.stats.safetyScore) * 0.9 + Double(safetyPoints) * 0.1))
        
        currentUser = User(
            id: user.id,
            username: user.username,
            email: user.email,
            firstName: user.firstName,
            lastName: user.lastName,
            phone: user.phone,
            bio: user.bio,
            bike: user.bike,
            ridingExperience: user.ridingExperience,
            stats: updatedStats,
            postsCount: user.postsCount,
            followersCount: user.followersCount,
            followingCount: user.followingCount,
            status: user.status,
            locationSharingEnabled: user.locationSharingEnabled,
            isVerified: user.isVerified,
            followers: user.followers,
            following: user.following,
            badges: user.badges,
            rank: user.rank,
            joinDate: user.joinDate
        )
        
        // User stats are persisted through API, no need for local save
    }
    
    func getBadges() -> [Badge] {
        guard let user = currentUser else { return [] }
        
        var badges: [Badge] = []
        
        // Distance badges
        if user.stats.totalMiles >= 1000 {
            badges.append(Badge(
                id: UUID(),
                name: "Iron Rider",
                description: "Rode 1,000+ miles",
                iconName: "🏍️",
                earnedDate: Date()
            ))
        }
        if user.stats.totalMiles >= 5000 {
            badges.append(Badge(
                id: UUID(),
                name: "Road Warrior",
                description: "Rode 5,000+ miles",
                iconName: "⚡",
                earnedDate: Date()
            ))
        }
        
        // Safety badges
        if user.stats.safetyScore >= 95 {
            badges.append(Badge(
                id: UUID(),
                name: "Safety Champion",
                description: "Maintained 95%+ safety score",
                iconName: "🛡️",
                earnedDate: Date()
            ))
        }
        
        return badges
    }
    
    // MARK: - Notification Management
    func addNotification(_ notification: AppNotification) {
        notifications.insert(notification, at: 0) // Add to beginning
        if !notification.isRead {
            unreadNotificationsCount += 1
        }
    }
    
    func markNotificationsAsRead() {
        notifications = notifications.map { notification in
            var updated = notification
            updated.isRead = true
            return updated
        }
        unreadNotificationsCount = 0
        print("✅ Marked all notifications as read - badge cleared")
    }
    
    func clearOldNotifications() {
        // Keep only last 20 notifications
        if notifications.count > 20 {
            notifications = Array(notifications.prefix(20))
        }
    }
    
    private func addSampleNotifications() {
        let sampleNotifications = [
            AppNotification(
                id: UUID(),
                type: "newFollower",
                title: "New Follower",
                message: "SpeedDemon started following you",
                timestamp: Date().addingTimeInterval(-3600),
                isRead: false
            )
        ]
        
        for notification in sampleNotifications {
            addNotification(notification)
        }
    }
    
    // MARK: - Private Methods
    private func updateUserStats(with rideData: RideData) {
        guard let user = currentUser else { return }
        
        var updatedStats = user.stats
        
        // Convert distance from meters to miles for consistency
        let rideDistanceMiles = rideData.distance * 0.000621371
        
        // Update core metrics
        updatedStats.totalMiles += rideDistanceMiles
        updatedStats.totalRides += 1
        
        // Update average speed as weighted average
        let totalRides = Double(updatedStats.totalRides)
        updatedStats.averageSpeed = ((updatedStats.averageSpeed * (totalRides - 1)) + rideData.averageSpeed) / totalRides
        
        // Update longest ride if this ride was longer
        if rideDistanceMiles > updatedStats.longestRide {
            updatedStats.longestRide = rideDistanceMiles
        }
        
        // Calculate safety score based on ride performance
        var safetyPoints = 100
        
        // Speed-based safety calculation
        if rideData.maxSpeed > 85 {
            safetyPoints -= min(15, Int((rideData.maxSpeed - 85) / 2)) // Deduct up to 15 points for excessive speed
        }
        
        // Consistency bonus (smooth riding)
        let speedVariance = abs(rideData.averageSpeed - (rideData.maxSpeed * 0.7))
        if speedVariance < 10 {
            safetyPoints += 5 // Bonus for consistent riding
        }
        
        // Duration consideration (fatigue factor)
        if rideData.duration > 14400 { // More than 4 hours
            safetyPoints -= 3 // Slight deduction for potential fatigue
        }
        
        // Update safety score as weighted average (90% old, 10% new)
        updatedStats.safetyScore = Int(Double(updatedStats.safetyScore) * 0.9 + Double(safetyPoints) * 0.1)
        
        // Ensure safety score stays within bounds
        updatedStats.safetyScore = max(0, min(100, updatedStats.safetyScore))
        
        // Update rank based on new total score
        let newRank = calculateDynamicRank(for: updatedStats)
        
        currentUser = User(
            id: user.id,
            username: user.username,
            email: user.email,
            firstName: user.firstName,
            lastName: user.lastName,
            phone: user.phone,
            bio: user.bio,
            bike: user.bike,
            ridingExperience: user.ridingExperience,
            stats: updatedStats,
            postsCount: user.postsCount,
            followersCount: user.followersCount,
            followingCount: user.followingCount,
            status: user.status,
            locationSharingEnabled: user.locationSharingEnabled,
            isVerified: user.isVerified,
            followers: user.followers,
            following: user.following,
            badges: user.badges,
            rank: newRank,
            joinDate: user.joinDate
        )
        
        // User stats are persisted through API, no need for local save
        
        // Trigger leaderboard update to reflect new stats
        updateLeaderboard()
        
        print("✅ Updated user stats: \(updatedStats.totalMiles) miles, \(updatedStats.totalRides) rides, safety: \(updatedStats.safetyScore)")
    }
    
    private func calculateDynamicRank(for stats: UserStats) -> Int {
        // Calculate rank based on composite score similar to leaderboard
        let userScore = Double(stats.totalMiles) * 0.6 + Double(stats.safetyScore) * 100 * 0.3 + Double(stats.totalRides) * 50 * 0.1
        
        // Compare against current leaderboard
        let betterUsers = leaderboard.filter { 
            calculateLeaderboardScore(for: $0.user) > userScore
        }
        
        return max(1, betterUsers.count + 1)
    }
    
    // MARK: - Real-time Profile Data Integration
    func updateProfileWithRealData() {
        guard let user = currentUser else { return }
        
        // In real app, would integrate with LocationManager for real ride data
        // For now, simulate ride data
        let mockRideStartTime = Date().addingTimeInterval(-3600) // Started 1 hour ago
        let mockCurrentRideDistance = 25000.0 // 25km in meters
        
        // Simulate currently on a ride for demo
        if true { // In real app: if let rideStartTime = locationManager.rideStartTime
            let rideStartTime = mockRideStartTime
            let currentRideDistance = mockCurrentRideDistance
            let currentRideDuration = Date().timeIntervalSince(rideStartTime)
            
            // Update temporary stats display (not permanent until ride ends)
            var tempStats = user.stats
            tempStats.totalMiles += currentRideDistance * 0.000621371 // Add current ride distance
            
            // Calculate current average speed for this ride
            if currentRideDuration > 0 {
                let currentRideSpeed = (currentRideDistance * 0.000621371) / (currentRideDuration / 3600.0) // mph
                
                // Update display stats (temporary)
                if currentRideSpeed > 0 {
                    tempStats.averageSpeed = currentRideSpeed
                }
            }
            
            // Create temporary user for display (doesn't save)
            let tempUser = User(
                id: user.id,
                username: user.username,
                email: user.email,
                firstName: user.firstName,
                lastName: user.lastName,
                phone: user.phone,
                bio: user.bio,
                bike: user.bike,
                ridingExperience: user.ridingExperience,
                stats: tempStats,
                postsCount: user.postsCount,
                followersCount: user.followersCount,
                followingCount: user.followingCount,
                status: user.status,
                locationSharingEnabled: user.locationSharingEnabled,
                isVerified: user.isVerified,
                followers: user.followers,
                following: user.following,
                badges: user.badges,
                rank: user.rank,
                joinDate: user.joinDate
            )
            
            // Only update currentUser temporarily for display
            currentUser = tempUser
        }
        
        // Update weekly/monthly stats based on timeframe
        calculateTimebasedStats()
    }
    
    private func calculateTimebasedStats() {
        guard let user = currentUser else { return }
        
        // Calculate stats for different timeframes based on posts and activities
        let calendar = Calendar.current
        let now = Date()
        
        // Weekly stats (last 7 days)
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let weeklyPosts = feedPosts.filter { $0.timestamp >= weekAgo && $0.userId == user.id.uuidString }
        let weeklyMiles = weeklyPosts.compactMap { $0.rideData?.distance }.reduce(0, +)
        
        // Monthly stats (last 30 days)
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let monthlyPosts = feedPosts.filter { $0.timestamp >= monthAgo && $0.userId == user.id.uuidString }
        let monthlyMiles = monthlyPosts.compactMap { $0.rideData?.distance }.reduce(0, +)
        
        // Store calculated timeframe stats (could extend UserStats to include these)
        UserDefaults.standard.set(Int(weeklyMiles * 0.000621371), forKey: "weeklyMiles")
        UserDefaults.standard.set(Int(monthlyMiles * 0.000621371), forKey: "monthlyMiles")
        
        print("✅ Calculated timeframe stats: Weekly: \(Int(weeklyMiles * 0.000621371)) mi, Monthly: \(Int(monthlyMiles * 0.000621371)) mi")
    }
    
    // Sample data removed - all data should come from database
    
    // Sample user creation removed - all users should come from database
    
    // MARK: - Search Methods
    
    func searchUsers(query: String) -> AnyPublisher<[SearchUser], Error> {
        networkManager.searchUsersGeneral(query: query)
            .map { response in response.users }
            .eraseToAnyPublisher()
    }
    
    func searchPosts(query: String) -> AnyPublisher<[Post], Error> {
        networkManager.searchPosts(query: query)
            .map { response in response.posts }
            .eraseToAnyPublisher()
    }
    
    func searchStories(query: String) -> AnyPublisher<[SearchStory], Error> {
        networkManager.searchStories(query: query)
            .map { response in response.stories }
            .eraseToAnyPublisher()
    }
    
    func searchPacks(query: String) -> AnyPublisher<[SearchPack], Error> {
        networkManager.searchPacks(query: query)
            .map { response in response.packs }
            .eraseToAnyPublisher()
    }
    
    func searchRides(query: String) -> AnyPublisher<[SearchRide], Error> {
        networkManager.searchRides(query: query)
            .map { response in response.rides }
            .eraseToAnyPublisher()
    }
    
    func searchAll(query: String) -> AnyPublisher<SearchResults, Error> {
        networkManager.searchAll(query: query)
            .map { response in response.results }
            .eraseToAnyPublisher()
    }
    
    func getSearchSuggestions(query: String) -> AnyPublisher<[SearchSuggestion], Error> {
        networkManager.getSearchSuggestions(query: query)
            .map { response in response.suggestions }
            .eraseToAnyPublisher()
    }
    
    func getUserProfile(username: String) -> AnyPublisher<BackendUser, Error> {
        networkManager.getUserByUsername(username)
            .map { response in response.user }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Friends Management
    func addFriend(byUsername username: String) {
        NetworkManager.shared.getUserByUsername(username)
            .flatMap { response -> AnyPublisher<MessageResponse, Error> in
                let userId = String(response.user.id)
                return NetworkManager.shared.followUser(userId: userId)
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ Add friend error: \(error)")
                }
            }, receiveValue: { resp in
                print("✅ Friend add response: \(resp.message)")
            })
            .store(in: &cancellables)
    }
    
    func getFriend(byUsername username: String) -> AnyPublisher<BackendUser, Error> {
        NetworkManager.shared.getUserByUsername(username)
            .map { response in response.user }
            .eraseToAnyPublisher()
    }
}

// MARK: - Data Models
// Note: All data models (User, Post, Comment, Challenge, RideGroup, Badge) are now defined in DataModels.swift to avoid conflicts

struct LeaderboardEntry: Identifiable {
    let id = UUID()
    let user: User
    let rank: Int
}

enum ChallengeType {
    case distance
    case safety
    case rides
} 