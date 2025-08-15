import Foundation
import CoreLocation
import SwiftUI


// MARK: - User Model
struct User: Identifiable, Codable {
    let id: UUID
    let username: String
    let email: String
    var firstName: String?
    var lastName: String?
    var phone: String?
    var bio: String
    var bike: String
    var motorcycleMake: String?
    var motorcycleModel: String?
    var motorcycleYear: Int?
    var profilePictureUrl: String?
    var ridingExperience: RidingExperience
    var stats: UserStats
    var postsCount: Int
    var followersCount: Int
    var followingCount: Int
    var status: UserStatus
    var locationSharingEnabled: Bool
    var isVerified: Bool
    var followers: [User]
    var following: [User]
    var badges: [Badge]
    var rank: Int
    var joinDate: Date
    
    enum RidingExperience: String, Codable, CaseIterable {
        case beginner = "beginner"
        case intermediate = "intermediate"
        case advanced = "advanced"
        case expert = "expert"
    }
    
    enum UserStatus: String, Codable {
        case online = "online"
        case offline = "offline"
        case riding = "riding"
    }
}

// MARK: - Backend User Model
struct BackendUser: Codable, Identifiable {
    let id: Int
    let username: String
    let email: String
    let firstName: String?
    let lastName: String?
    let phone: String?
    let bio: String?
    let motorcycleMake: String?
    let motorcycleModel: String?
    let motorcycleYear: Int?
    let profilePictureUrl: String?
    let ridingExperience: String?
    let totalMiles: Double?
    let totalRides: Int?
    let safetyScore: Int?
    let postsCount: Int?
    let followersCount: Int?
    let followingCount: Int?
    let status: String?
    let locationSharingEnabled: Bool?
    let isVerified: Bool?
    let createdAt: String
    let updatedAt: String
    let role: String?
    let subscriptionTier: String?
    
    func toUser() -> User {
        return User(
            id: UUID(),
            username: username,
            email: email,
            firstName: firstName,
            lastName: lastName,
            phone: phone,
            bio: bio ?? "",
            bike: "\(motorcycleMake ?? "") \(motorcycleModel ?? "")".trimmingCharacters(in: .whitespaces),
            motorcycleMake: motorcycleMake,
            motorcycleModel: motorcycleModel,
            motorcycleYear: motorcycleYear,
            profilePictureUrl: profilePictureUrl,
            ridingExperience: User.RidingExperience(rawValue: ridingExperience ?? "beginner") ?? .beginner,
            stats: UserStats(
                totalMiles: totalMiles ?? 0,
                totalRides: totalRides ?? 0,
                safetyScore: safetyScore ?? 100,
                averageSpeed: 0,
                longestRide: 0
            ),
            postsCount: postsCount ?? 0,
            followersCount: followersCount ?? 0,
            followingCount: followingCount ?? 0,
            status: User.UserStatus(rawValue: status ?? "offline") ?? .offline,
            locationSharingEnabled: locationSharingEnabled ?? false,
            isVerified: isVerified ?? false,
            followers: [],
            following: [],
            badges: [],
            rank: followersCount ?? 0,
            joinDate: createdAt.toDate() ?? Date()
        )
    }
}

// MARK: - Backend Post Model
struct BackendPost: Codable {
    let id: Int
    let userId: Int
    let username: String
    let content: String?
    let imageUrl: String?
    let videoUrl: String?
    let locationLat: Double?
    let locationLng: Double?
    let locationName: String?
    let rideId: Int?
    let timestamp: String
    let likesCount: Int
    let commentsCount: Int
    let isLiked: Bool
    let rideData: RideData?
    
    enum CodingKeys: String, CodingKey {
        case id, userId, username, content, timestamp, likesCount, commentsCount, isLiked, rideData
        case imageUrl = "image_url"
        case videoUrl = "video_url"
        case locationLat = "location_lat"
        case locationLng = "location_lng"
        case locationName = "location_name"
        case rideId = "ride_id"
    }
}

// MARK: - Backend Comment Model
struct BackendComment: Codable {
    let id: Int
    let postId: Int
    let userId: Int
    let username: String
    let firstName: String?
    let lastName: String?
    let profilePicture: String?
    let content: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, content, username
        case postId = "post_id"
        case userId = "user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case profilePicture = "profile_picture"
        case createdAt = "created_at"
    }
}

// MARK: - User Stats
struct UserStats: Codable {
    var totalMiles: Double
    var totalRides: Int
    var safetyScore: Int
    var averageSpeed: Double
    var longestRide: Double
    
    init(totalMiles: Double = 0, totalRides: Int = 0, safetyScore: Int = 100, averageSpeed: Double = 0, longestRide: Double = 0) {
        self.totalMiles = totalMiles
        self.totalRides = totalRides
        self.safetyScore = safetyScore
        self.averageSpeed = averageSpeed
        self.longestRide = longestRide
    }
}

// MARK: - Post Model
struct Post: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let content: String
    let timestamp: Date
    var likesCount: Int
    var commentsCount: Int
    var isLiked: Bool
    let rideData: RideData?
}

// MARK: - Comment Model  
struct Comment: Identifiable, Codable {
    let id: String
    let postId: String
    let userId: String
    let username: String
    let content: String
    let timestamp: Date
    var likesCount: Int
}

// MARK: - Ride Model
struct Ride: Identifiable, Codable {
    let id: UUID
    let userId: UUID?
    let title: String?
    let date: Date
    let distance: Double
    let duration: TimeInterval
    let averageSpeed: Double
    let maxSpeed: Double
    let startLocation: String
    let endLocation: String
    let safetyScore: Int
    
    var routePoints: [RoutePoint] = []
    
    struct RoutePoint: Codable {
        let latitude: Double
        let longitude: Double
    }
}

// MARK: - Ride Data Model
struct RideData: Codable {
    let distance: Double
    let duration: TimeInterval
    let averageSpeed: Double
    let maxSpeed: Double
    let safetyScore: Int
}

// MARK: - Emergency Event Model
struct EmergencyEvent: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let eventType: EmergencyType
    let severity: Severity
    let latitude: Double?
    let longitude: Double?
    let locationDescription: String?
    let description: String?
    let status: EmergencyStatus
    let createdAt: Date
    
    enum EmergencyType: String, Codable, CaseIterable {
        case crash = "crash"
        case breakdown = "breakdown"
        case medical = "medical"
        case other = "other"
    }
    
    enum Severity: String, Codable, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
    }
    
    enum EmergencyStatus: String, Codable {
        case active = "active"
        case responding = "responding"
        case resolved = "resolved"
        case cancelled = "cancelled"
    }
}

// MARK: - Hazard Report Model
struct HazardReport: Identifiable, Codable {
    let id: UUID
    let reporterId: UUID
    let hazardType: HazardType
    let severity: Severity
    let latitude: Double
    let longitude: Double
    let locationDescription: String?
    let description: String
    let confirmationsCount: Int
    let isResolved: Bool
    let createdAt: Date
    
    enum HazardType: String, Codable, CaseIterable {
        case pothole = "pothole"
        case debris = "debris"
        case construction = "construction"
        case weather = "weather"
        case animal = "animal"
        case accident = "accident"
        case other = "other"
    }
    
    enum Severity: String, Codable, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
    }
}

// MARK: - Analytics Event Model
struct AnalyticsEvent: Codable {
    let eventType: String
    let eventCategory: String
    let sessionId: String?
    let deviceType: String
    let appVersion: String
    let timestamp: Date
    
    init(eventType: String, eventCategory: String, sessionId: String? = nil, deviceType: String = "ios", appVersion: String = "1.0.0", timestamp: Date = Date()) {
        self.eventType = eventType
        self.eventCategory = eventCategory
        self.sessionId = sessionId
        self.deviceType = deviceType
        self.appVersion = appVersion
        self.timestamp = timestamp
    }
}

// MARK: - Weather Models
struct WeatherData {
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let windSpeed: Double
    let windDirection: Int
    let precipitation: Double
    let visibility: Int
    let conditions: String
    let iconCode: String
    let locationName: String
    let timestamp: Date
    
    init(temperature: Double, feelsLike: Double, humidity: Int, windSpeed: Double, windDirection: Int, precipitation: Double, visibility: Int, conditions: String, iconCode: String, locationName: String, timestamp: Date = Date()) {
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.precipitation = precipitation
        self.visibility = visibility
        self.conditions = conditions
        self.iconCode = iconCode
        self.locationName = locationName
        self.timestamp = timestamp
    }
    
    init(from response: OpenWeatherResponse) {
        self.temperature = response.main.temp
        self.feelsLike = response.main.feels_like
        self.humidity = response.main.humidity
        self.windSpeed = response.wind?.speed ?? 0
        self.windDirection = response.wind?.deg ?? 0
        self.precipitation = response.rain?.oneHour ?? response.snow?.oneHour ?? 0
        self.visibility = response.visibility ?? 10000
        self.conditions = response.weather.first?.main ?? "Unknown"
        self.iconCode = response.weather.first?.icon ?? "01d"
        self.locationName = response.name
        self.timestamp = Date()
    }
    
    init(from response: OpenMeteoResponse, coordinate: CLLocationCoordinate2D) {
        self.temperature = response.current.temperature_2m
        self.feelsLike = response.current.temperature_2m // Open-Meteo doesn't provide feels-like in basic plan
        self.humidity = response.current.relative_humidity_2m
        self.windSpeed = response.current.wind_speed_10m
        self.windDirection = response.current.wind_direction_10m
        self.precipitation = 0 // Would need additional API call for precipitation
        self.visibility = 10 // Default visibility
        self.conditions = WeatherData.weatherCodeToCondition(response.current.weather_code)
        self.iconCode = "01d" // Default icon
        self.locationName = "Current Location"
        self.timestamp = Date()
    }
    
    private static func weatherCodeToCondition(_ code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1, 2, 3: return "Partly Cloudy"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rain"
        case 71, 73, 75: return "Snow"
        case 80, 81, 82: return "Rain Showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Unknown"
        }
    }
}

extension WeatherData {
    var iconName: String {
        switch conditions.lowercased() {
        case "clear":
            return "sun.max.fill"
        case "clouds":
            return "cloud.fill"
        case "rain", "drizzle":
            return "cloud.rain.fill"
        case "snow":
            return "cloud.snow.fill"
        case "thunderstorm":
            return "cloud.bolt.fill"
        case "mist", "fog", "haze":
            return "cloud.fog.fill"
        default:
            return "cloud.fill"
        }
    }
}

struct WeatherAlert: Identifiable {
    let id: String
    let type: WeatherAlertType
    let location: CLLocationCoordinate2D
    let severity: AlertSeverity
    let description: String
    let timestamp: Date
    
    init(id: String = UUID().uuidString, type: WeatherAlertType, location: CLLocationCoordinate2D, severity: AlertSeverity, description: String) {
        self.id = id
        self.type = type
        self.location = location
        self.severity = severity
        self.description = description
        self.timestamp = Date()
    }
    
    init(id: String, type: WeatherAlertType, severity: AlertSeverity, title: String, message: String, location: String) {
        self.id = id
        self.type = type
        self.location = CLLocationCoordinate2D(latitude: 0, longitude: 0) // Default location for API-based alerts
        self.severity = severity
        self.description = "\(title): \(message)"
        self.timestamp = Date()
    }
}

enum WeatherAlertType: String, CaseIterable {
    case rain = "rain"
    case wind = "wind"
    case temperature = "temperature"
    case visibility = "visibility"
    case severe = "severe"
    case lowVisibility = "low_visibility"
    case precipitation = "precipitation"
    case strongWinds = "strong_winds"
    case temperatureExtreme = "temperature_extreme"
    
    var icon: String {
        switch self {
        case .rain, .precipitation: return "cloud.rain.fill"
        case .wind, .strongWinds: return "wind"
        case .temperature, .temperatureExtreme: return "thermometer.snowflake"
        case .visibility, .lowVisibility: return "eye.slash.fill"
        case .severe: return "exclamationmark.triangle.fill"
        }
    }
}

enum AlertSeverity: Int, CaseIterable, Codable {
    case low = 1
    case medium = 2
    case moderate = 3
    case high = 4
    case severe = 5
    case critical = 6
    
    // For backwards compatibility with string-based usage
    var stringValue: String {
        switch self {
        case .low: return "low"
        case .medium, .moderate: return "medium"
        case .high, .severe: return "high"
        case .critical: return "critical"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "yellow"
        case .medium, .moderate: return "orange"
        case .high, .severe: return "red"
        case .critical: return "purple"
        }
    }
    
    static func fromConfidence(_ confidence: Double) -> AlertSeverity {
        if confidence > 0.9 { return .critical }
        if confidence > 0.8 { return .high }
        if confidence > 0.6 { return .moderate }
        return .low
    }
}

// MARK: - OpenWeather API Models
struct OpenWeatherResponse: Codable {
    let main: MainWeather
    let weather: [WeatherCondition]
    let wind: Wind?
    let rain: Precipitation?
    let snow: Precipitation?
    let visibility: Int?
    let name: String
}

struct MainWeather: Codable {
    let temp: Double
    let feels_like: Double
    let humidity: Int
}

struct WeatherCondition: Codable {
    let main: String
    let description: String
    let icon: String
}

struct Wind: Codable {
    let speed: Double
    let deg: Int?
}

struct Precipitation: Codable {
    let oneHour: Double?
    
    enum CodingKeys: String, CodingKey {
        case oneHour = "1h"
    }
}

struct WeatherAlertsResponse: Codable {
    let alerts: [OpenWeatherAlert]?
}

struct OpenWeatherAlert: Codable {
    let sender_name: String
    let event: String
    let description: String
    let start: TimeInterval
    let end: TimeInterval
}

// MARK: - Notification Model
struct MotoRevNotification: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let type: String
    let title: String
    let message: String
    var isRead: Bool
    let createdAt: Date
    
    enum Name: String {
        case emergencyDetected = "EmergencyDetected"
        case crashDetected = "CrashDetected"
        case hazardReported = "HazardReported"
        case rideCompleted = "RideCompleted"
        case followRequest = "FollowRequest"
        case messageReceived = "MessageReceived"
    }
}

// MARK: - App Notification Model
struct AppNotification: Identifiable, Codable {
    let id: UUID
    let type: String
    let title: String
    let message: String
    let timestamp: Date
    var isRead: Bool
}

// MARK: - Emergency Contact Model
struct EmergencyContact: Identifiable, Codable {
    let id: UUID
    var name: String
    var phoneNumber: String
    var relationship: String
    var isPrimary: Bool
    
    init(id: UUID = UUID(), name: String, phoneNumber: String, relationship: String, isPrimary: Bool = false) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.relationship = relationship
        self.isPrimary = isPrimary
    }
}

// MARK: - Story Models
struct Story: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let username: String
    let content: String
    let mediaUrl: String?
    let timestamp: Date
    let expiresAt: Date
    var viewsCount: Int
}

struct StoryGroup: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let username: String
    let userProfilePicture: String?
    let stories: [Story]
    let latestStoryTimestamp: Date
    var hasUnviewedStories: Bool
}

// MARK: - Challenge Model
struct Challenge: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let type: ChallengeType
    let targetValue: Double
    let currentValue: Double
    let unit: String
    let startDate: Date
    let endDate: Date
    let participants: [String]
    let reward: String?
    
    // Computed properties
    var isCompleted: Bool {
        return currentValue >= targetValue
    }
    
    var progress: Double {
        return min(currentValue / targetValue, 1.0)
    }
    
    enum ChallengeType: String, Codable {
        case distance = "distance"
        case rides = "rides"
        case safety = "safety"
        case social = "social"
    }
}

// MARK: - Ride Group Model
struct RideGroup: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let creatorId: UUID
    let members: [User]
    let maxMembers: Int
    let isPrivate: Bool
    let scheduledDate: Date?
    let route: String?
    let difficulty: Difficulty
    let createdAt: Date
    let location: String
    
    // Computed properties
    var memberCount: Int {
        return members.count
    }
    
    var nextRideDate: String {
        if let scheduledDate = scheduledDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: scheduledDate)
        }
        return "TBD"
    }
    
    var isActive: Bool {
        if let scheduledDate = scheduledDate {
            return scheduledDate > Date()
        }
        return false
    }
    
    enum Difficulty: String, Codable {
        case easy = "easy"
        case moderate = "moderate"
        case hard = "hard"
        case expert = "expert"
    }
}

// MARK: - Activity Item Model
struct ActivityItem: Identifiable, Codable {
    let id: UUID
    let type: ActivityType
    let title: String
    let description: String
    let timestamp: Date
    let userId: UUID?
    let username: String?
    
    enum ActivityType: String, Codable {
        case like = "like"
        case comment = "comment"
        case follow = "follow"
        case ride = "ride"
        case badge = "badge"
        case challenge = "challenge"
    }
}

// MARK: - Verified Location Model
struct VerifiedLocation: Codable {
    let coordinate: CLLocationCoordinate2D
    let accuracy: Double
    let timestamp: Date
    let isVerified: Bool
    let nearestAddress: String
    let crossReferencedAddress: String?
    let landmarks: [String]
    let confidence: Double
    
    init(coordinates: CLLocationCoordinate2D, accuracy: Double, nearestAddress: String, crossReferencedAddress: String?, landmarks: [String], confidence: Double, timestamp: Date) {
        self.coordinate = coordinates
        self.accuracy = accuracy
        self.nearestAddress = nearestAddress
        self.crossReferencedAddress = crossReferencedAddress
        self.landmarks = landmarks
        self.confidence = confidence
        self.timestamp = timestamp
        self.isVerified = confidence > 0.8
    }
}

// MARK: - Location Models
struct NearbyRider: Identifiable, Codable {
    let id: UUID
    let name: String
    let bike: String
    let location: CLLocationCoordinate2D
    let distance: Double
    let isRiding: Bool
    let lastSeen: Date
}

struct APINearbyRider: Codable {
    let id: UUID
    let name: String
    let bike: String
    let latitude: Double
    let longitude: Double
    let distance: Double
    let isRiding: Bool
    let lastSeen: Date
}

// MARK: - Badge Model
struct Badge: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let iconName: String
    let earnedDate: Date
}

// MARK: - Navigation Models
struct NavigationInstruction: Identifiable, Codable {
    let id: UUID
    let text: String
    let distance: Double
    let maneuver: ManeuverType
    
    init(text: String, distance: Double, maneuver: ManeuverType) {
        self.id = UUID()
        self.text = text
        self.distance = distance
        self.maneuver = maneuver
    }
    
    enum ManeuverType: String, Codable {
        case straight = "straight"
        case left = "left"
        case right = "right"
        case slightLeft = "slight_left"
        case slightRight = "slight_right"
        case sharpLeft = "sharp_left"
        case sharpRight = "sharp_right"
        case uturn = "uturn"
        case arrive = "arrive"
        case merge = "merge"
        case roundabout = "roundabout"
    }
}

// MARK: - Response Models
struct AuthResponse: Codable {
    let success: Bool
    let token: String?
    let user: BackendUser?
    let message: String?
}

struct UserResponse: Codable {
    let user: BackendUser
}

struct UserUpdateResponse: Codable {
    let success: Bool
    let user: BackendUser?
    let message: String?
}

struct UsersResponse: Codable {
    let success: Bool
    let users: [User]
    let message: String?
}

struct EmergencyResponse: Codable {
    let success: Bool
    let emergencyEvent: EmergencyEvent?
    let message: String?
}

struct HazardResponse: Codable {
    let success: Bool
    let hazardReport: HazardReport?
    let message: String?
}

struct NearbyRidersResponse: Codable {
    let success: Bool
    let riders: [APINearbyRider]?
    let message: String?
}

struct RidesResponse: Codable {
    let success: Bool
    let rides: [Ride]
    let message: String?
}

struct PostsResponse: Codable {
    let success: Bool
    let posts: [Post]
    let message: String?
}

struct PostResponse: Codable {
    let success: Bool
    let post: Post
    let message: String?
}

struct RideResponse: Codable {
    let success: Bool
    let ride: Ride
    let message: String?
}

struct MessageResponse: Codable {
    let success: Bool
    let message: String
}

struct CommentsResponse: Codable {
    let success: Bool
    let comments: [Comment]?
    let message: String?
}

struct CommentResponse: Codable {
    let success: Bool
    let comment: Comment
    let message: String?
}

// MARK: - Helper Extensions
extension String {
    func toDate() -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: self)
    }
}

extension CLLocationCoordinate2D: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    private enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }
}

// MARK: - Helper Models
struct EmptyBody: Codable, Sendable {}

struct ErrorResponse: Codable {
    let error: String
}

struct LikeResponse: Codable {
    let message: String
    let liked: Bool
}

// MARK: - Medical Info Model
struct MedicalInfo: Codable {
    let bloodType: String
    let allergies: [String]
    let medications: [String]
    let medicalID: String?
    let conditions: [String]
    let emergencyNotes: String?
} 

// MARK: - Request Models
struct LoginRequest: Codable {
    let username: String
    let password: String
}

struct CreatePostRequest: Codable {
    let content: String?
    let imageUrl: String?
    let videoUrl: String?
    let location: String?
    let rideId: String?
}

struct CreateCommentRequest: Codable {
    let content: String
}

struct UpdateProfileRequest: Codable {
    let firstName: String?
    let lastName: String?
    let phoneNumber: String?
    let motorcycleMake: String?
    let motorcycleModel: String?
    let motorcycleYear: String?
    let ridingExperience: String?
    let bio: String?
    let profilePicture: String?
}

// MARK: - Additional API Response Models
struct LoginResponse: Codable {
    let message: String
    let user: BackendUser
    let token: String
    let expiresIn: String
}

struct CreatePostResponse: Codable {
    let message: String
    let post: BackendPost
}

struct CreateCommentResponse: Codable {
    let message: String
    let comment: BackendComment
}

struct UpdateProfileResponse: Codable {
    let message: String
    let user: BackendUser
}

// MARK: - Search Response Models
struct SearchUsersResponse: Codable {
    let success: Bool
    let users: [SearchUser]
    let query: String
    let total: Int
}

struct SearchUser: Codable, Identifiable {
    let id: Int
    let username: String
    let firstName: String?
    let lastName: String?
    let profilePicture: String?
    let motorcycleMake: String?
    let motorcycleModel: String?
    let safetyScore: Int?
    let totalRides: Int?
    let bio: String?
    let isVerified: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, username, bio
        case firstName = "first_name"
        case lastName = "last_name"
        case profilePicture = "profile_picture"
        case motorcycleMake = "motorcycle_make"
        case motorcycleModel = "motorcycle_model"
        case safetyScore = "safety_score"
        case totalRides = "total_rides"
        case isVerified = "is_verified"
    }
}

struct StoriesResponse: Codable {
    let success: Bool
    let stories: [SearchStory]
    let query: String
    let total: Int
}

struct SearchStory: Codable, Identifiable {
    let id: Int
    let userId: Int
    let content: String?
    let imageUrl: String?
    let videoUrl: String?
    let backgroundColor: String?
    let username: String
    let firstName: String?
    let lastName: String?
    let profilePicture: String?
    let createdAt: String
    let expiresAt: String
    let isViewed: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, content, username
        case userId = "user_id"
        case imageUrl = "image_url"
        case videoUrl = "video_url"
        case backgroundColor = "background_color"
        case firstName = "first_name"
        case lastName = "last_name"
        case profilePicture = "profile_picture"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case isViewed = "is_viewed"
    }
}

struct PacksResponse: Codable {
    let success: Bool
    let packs: [SearchPack]
    let query: String
    let total: Int
}

struct SearchPack: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let leaderUsername: String
    let leaderFirstName: String?
    let leaderLastName: String?
    let memberCount: Int
    let maxMembers: Int?
    let packType: String?
    let privacyLevel: String?
    let status: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, status
        case leaderUsername = "leader_username"
        case leaderFirstName = "leader_first_name"
        case leaderLastName = "leader_last_name"
        case memberCount = "member_count"
        case maxMembers = "max_members"
        case packType = "pack_type"
        case privacyLevel = "privacy_level"
        case createdAt = "created_at"
    }
}

struct SearchRidesResponse: Codable {
    let success: Bool
    let rides: [SearchRide]
    let query: String
    let total: Int
}

struct SearchRide: Codable, Identifiable {
    let id: Int
    let userId: Int
    let title: String?
    let startLocationName: String?
    let endLocationName: String?
    let distance: Double?
    let duration: Int?
    let averageSpeed: Double?
    let maxSpeed: Double?
    let status: String
    let visibility: String?
    let username: String
    let firstName: String?
    let lastName: String?
    let profilePictureUrl: String?
    let startTime: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, distance, duration, status, visibility, username
        case userId = "user_id"
        case startLocationName = "start_location_name"
        case endLocationName = "end_location_name"
        case averageSpeed = "average_speed"
        case maxSpeed = "max_speed"
        case firstName = "first_name"
        case lastName = "last_name"
        case profilePictureUrl = "profile_picture_url"
        case startTime = "start_time"
    }
}

struct GeneralSearchResponse: Codable {
    let success: Bool
    let results: SearchResults
    let query: String
    let total: Int
}

struct SearchResults: Codable {
    let users: [GeneralSearchUser]
    let posts: [GeneralSearchPost]
    let packs: [GeneralSearchPack]
}

struct GeneralSearchUser: Codable, Identifiable {
    let id: Int
    let username: String
    let firstName: String?
    let lastName: String?
    let profilePicture: String?
    let motorcycleMake: String?
    let motorcycleModel: String?
    let safetyScore: Int?
    let isVerified: Bool
    let contentType: String
    
    enum CodingKeys: String, CodingKey {
        case id, username
        case firstName = "first_name"
        case lastName = "last_name"
        case profilePicture = "profile_picture"
        case motorcycleMake = "motorcycle_make"
        case motorcycleModel = "motorcycle_model"
        case safetyScore = "safety_score"
        case isVerified = "is_verified"
        case contentType = "content_type"
    }
}

struct GeneralSearchPost: Codable, Identifiable {
    let id: Int
    let content: String
    let createdAt: String
    let username: String
    let profilePicture: String?
    let contentType: String
    
    enum CodingKeys: String, CodingKey {
        case id, content, username
        case createdAt = "created_at"
        case profilePicture = "profile_picture"
        case contentType = "content_type"
    }
}

struct GeneralSearchPack: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let createdAt: String
    let leaderUsername: String
    let contentType: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case createdAt = "created_at"
        case leaderUsername = "leader_username"
        case contentType = "content_type"
    }
} 

// MARK: - Search Suggestions Models
struct SearchSuggestionsResponse: Codable {
    let success: Bool
    let suggestions: [SearchSuggestion]
    let query: String
}

struct SearchSuggestion: Codable, Identifiable {
    let id: Int
    let type: String
    let username: String
    let displayText: String
    let subtitle: String?
    let profilePicture: String?
    
    enum CodingKeys: String, CodingKey {
        case id, type, username, subtitle
        case displayText = "displayText"
        case profilePicture = "profilePicture"
    }
}

// MARK: - Digital Garage Models
struct Bike: Codable, Identifiable {
    let id: Int
    let userId: Int
    let name: String
    let year: Int?
    let make: String?
    let model: String?
    let color: String?
    let engineSize: String?
    let bikeType: BikeType
    let currentMileage: Int
    let purchaseDate: String?
    let notes: String?
    let isPrimary: Bool
    let photos: [String]
    let modifications: [BikeModification]
    let createdAt: String
    let updatedAt: String
    
    enum BikeType: String, Codable, CaseIterable {
        case sport = "sport"
        case touring = "touring"
        case cruiser = "cruiser"
        case adventure = "adventure"
        case naked = "naked"
        case dirt = "dirt"
        case scooter = "scooter"
        case other = "other"
        
        var displayName: String {
            switch self {
            case .sport: return "Sport"
            case .touring: return "Touring"
            case .cruiser: return "Cruiser"
            case .adventure: return "Adventure"
            case .naked: return "Naked"
            case .dirt: return "Dirt/Off-road"
            case .scooter: return "Scooter"
            case .other: return "Other"
            }
        }
        
        var icon: String {
            switch self {
            case .sport: return "bolt.circle"
            case .touring: return "road.lanes"
            case .cruiser: return "sun.max"
            case .adventure: return "mountain.2"
            case .naked: return "wind"
            case .dirt: return "leaf"
            case .scooter: return "scooter"
            case .other: return "questionmark.circle"
            }
        }
    }
}

struct BikeModification: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let cost: Double?
    let installDate: String?
    let category: ModificationCategory
    
    enum ModificationCategory: String, Codable, CaseIterable {
        case performance = "performance"
        case aesthetic = "aesthetic"
        case comfort = "comfort"
        case safety = "safety"
        case other = "other"
        
        var displayName: String {
            switch self {
            case .performance: return "Performance"
            case .aesthetic: return "Aesthetic"
            case .comfort: return "Comfort"
            case .safety: return "Safety"
            case .other: return "Other"
            }
        }
    }
    
    init(id: UUID = UUID(), name: String, description: String? = nil, cost: Double? = nil, installDate: String? = nil, category: ModificationCategory = .other) {
        self.id = id
        self.name = name
        self.description = description
        self.cost = cost
        self.installDate = installDate
        self.category = category
    }
}

// MARK: - Maintenance Tracking Models
struct MaintenanceRecord: Codable, Identifiable {
    let id: Int
    let bikeId: Int
    let userId: Int
    let maintenanceType: MaintenanceType
    let title: String
    let description: String?
    let cost: Double?
    let mileageAtService: Int?
    let serviceDate: String
    let nextServiceMileage: Int?
    let nextServiceDate: String?
    let shopName: String?
    let partsUsed: [MaintenancePart]
    let photos: [String]
    let reminderEnabled: Bool
    let completed: Bool
    let createdAt: String
    let updatedAt: String
    
    enum MaintenanceType: String, Codable, CaseIterable {
        case oilChange = "oil_change"
        case chainService = "chain_service"
        case tireCheck = "tire_check"
        case brakeService = "brake_service"
        case airFilter = "air_filter"
        case sparkPlugs = "spark_plugs"
        case coolant = "coolant"
        case battery = "battery"
        case generalService = "general_service"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .oilChange: return "Oil Change"
            case .chainService: return "Chain/Belt Service"
            case .tireCheck: return "Tire Check"
            case .brakeService: return "Brake Service"
            case .airFilter: return "Air Filter"
            case .sparkPlugs: return "Spark Plugs"
            case .coolant: return "Coolant"
            case .battery: return "Battery"
            case .generalService: return "General Service"
            case .custom: return "Custom"
            }
        }
        
        var icon: String {
            switch self {
            case .oilChange: return "drop.fill"
            case .chainService: return "link"
            case .tireCheck: return "circle"
            case .brakeService: return "stop.circle"
            case .airFilter: return "wind"
            case .sparkPlugs: return "bolt.fill"
            case .coolant: return "thermometer"
            case .battery: return "battery.100"
            case .generalService: return "wrench.and.screwdriver"
            case .custom: return "gear"
            }
        }
        
        var defaultIntervalMiles: Int {
            switch self {
            case .oilChange: return 3000
            case .chainService: return 5000
            case .tireCheck: return 2000
            case .brakeService: return 10000
            case .airFilter: return 6000
            case .sparkPlugs: return 8000
            case .coolant: return 24000
            case .battery: return 12000
            case .generalService: return 6000
            case .custom: return 5000
            }
        }
        
        var defaultIntervalMonths: Int {
            switch self {
            case .oilChange: return 6
            case .chainService: return 12
            case .tireCheck: return 3
            case .brakeService: return 24
            case .airFilter: return 12
            case .sparkPlugs: return 12
            case .coolant: return 24
            case .battery: return 24
            case .generalService: return 12
            case .custom: return 12
            }
        }
    }
}

struct MaintenancePart: Codable, Identifiable {
    let id: UUID
    let name: String
    let partNumber: String?
    let brand: String?
    let cost: Double?
    let quantity: Int
    
    init(id: UUID = UUID(), name: String, partNumber: String? = nil, brand: String? = nil, cost: Double? = nil, quantity: Int = 1) {
        self.id = id
        self.name = name
        self.partNumber = partNumber
        self.brand = brand
        self.cost = cost
        self.quantity = quantity
    }
}

struct MaintenanceTemplate: Codable, Identifiable {
    let id: Int
    let bikeId: Int
    let maintenanceType: MaintenanceRecord.MaintenanceType
    let title: String
    let intervalMiles: Int?
    let intervalMonths: Int?
    let reminderMilesBefore: Int
    let reminderDaysBefore: Int
    let isActive: Bool
    let createdAt: String
    let updatedAt: String
}

// MARK: - Maintenance API Models
struct CreateMaintenanceRequest: Codable {
    let bikeId: Int
    let maintenanceType: String
    let title: String
    let description: String?
    let cost: Double?
    let mileageAtService: Int?
    let serviceDate: String
    let nextServiceMileage: Int?
    let nextServiceDate: String?
    let shopName: String?
    let partsUsed: [MaintenancePart]?
    let photos: [String]?
    let reminderEnabled: Bool
    let completed: Bool
}

struct UpdateMaintenanceRequest: Codable {
    let title: String
    let description: String?
    let cost: Double?
    let mileageAtService: Int?
    let serviceDate: String
    let nextServiceMileage: Int?
    let nextServiceDate: String?
    let shopName: String?
    let partsUsed: [MaintenancePart]?
    let photos: [String]?
    let reminderEnabled: Bool
    let completed: Bool
}

struct MaintenanceRecordsResponse: Codable {
    let success: Bool
    let records: [MaintenanceRecord]
}

struct MaintenanceRecordResponse: Codable {
    let success: Bool
    let record: MaintenanceRecord
    let message: String?
}

struct CreateBikeRequest: Codable {
    let name: String
    let year: Int?
    let make: String?
    let model: String?
    let color: String?
    let engineSize: String?
    let bikeType: String
    let currentMileage: Int
    let purchaseDate: String?
    let notes: String?
    let isPrimary: Bool
    let photos: [String]?
    let modifications: [BikeModification]?
}

struct UpdateBikeRequest: Codable {
    let name: String
    let year: Int?
    let make: String?
    let model: String?
    let color: String?
    let engineSize: String?
    let bikeType: String
    let currentMileage: Int
    let purchaseDate: String?
    let notes: String?
    let isPrimary: Bool
    let photos: [String]?
    let modifications: [BikeModification]?
}

struct CreateModificationRequest: Codable {
    let name: String
    let description: String?
    let category: String
    let installationDate: Date
    let cost: Double
    let installer: String?
    let warrantyInfo: String?
}

struct BikesResponse: Codable {
    let bikes: [Bike]
}

struct BikeResponse: Codable {
    let success: Bool
    let bike: Bike
    let message: String?
}

// MARK: - Group Ride Models
struct GroupRide: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String?
    let leaderId: String
    let leaderUsername: String
    let createdAt: String
    let startedAt: String?
    let endedAt: String?
    let status: String // "pending", "active", "completed"
    let memberCount: Int
    let maxMembers: Int?
    let isPrivate: Bool
    let inviteCode: String?
}

struct GroupMember: Codable, Identifiable, Sendable {
    let id: String
    let userId: String
    let username: String
    let firstName: String?
    let lastName: String?
    let profilePictureUrl: String?
    let role: String // "leader", "member"
    let joinedAt: String
    let isOnline: Bool
    let lastLocation: MemberLocation?
    let distanceFromLeader: Double?
    let safetyScore: Int?
}

struct MemberLocation: Codable, Sendable {
    let latitude: Double
    let longitude: Double
    let heading: Double?
    let speed: Double?
    let accuracy: Double?
    let timestamp: String
}

struct SharedRoute: Codable, Sendable {
    let id: String?
    let name: String
    let waypoints: [RouteWaypoint]
    let totalDistance: Double?
    let estimatedDuration: Int?
    let sharedBy: String?
    let sharedAt: String?
}

struct RouteWaypoint: Codable, Identifiable, Sendable {
    let id: String
    let latitude: Double
    let longitude: Double
    let name: String?
    let address: String?
    let order: Int
    let waypointType: String // "start", "waypoint", "destination"
}

struct GroupMessage: Codable, Identifiable, Sendable {
    let id: String
    let groupRideId: String
    let userId: String
    let username: String
    let content: String
    let messageType: String // "text", "location", "emergency", "system"
    let createdAt: String
    let metadata: MessageMetadata?
}

struct MessageMetadata: Codable, Sendable {
    let location: MemberLocation?
    let emergencyType: String?
    let systemEventType: String?
}

struct RideInvitation: Codable, Identifiable, Sendable {
    let id: String
    let groupRideId: String
    let groupRideName: String
    let fromUserId: String
    let fromUsername: String
    let toUserId: String
    let status: String // "pending", "accepted", "declined", "expired"
    let createdAt: String
    let expiresAt: String?
    let message: String?
}

// MARK: - OpenMeteo API Models
struct OpenMeteoResponse: Codable {
    let current: OpenMeteoCurrentWeather
}

struct OpenMeteoCurrentWeather: Codable {
    let temperature_2m: Double
    let relative_humidity_2m: Int
    let wind_speed_10m: Double
    let wind_direction_10m: Int
    let weather_code: Int
}

// MARK: - Fuel Logs API Models
struct CreateFuelLogRequest: Codable {
    let bikeId: Int?
    let date: String // ISO8601
    let stationName: String?
    let fuelType: String?
    let gallons: Double
    let pricePerGallon: Double
    let totalCost: Double
    let odometer: Int?
    let notes: String?
}

struct FuelLogItem: Codable, Identifiable {
    let id: Int
    let userId: Int
    let bikeId: Int?
    let logDate: String
    let stationName: String?
    let fuelType: String
    let gallons: Double
    let pricePerGallon: Double
    let totalCost: Double
    let odometer: Int?
    let notes: String?
    
    // Convenience properties for UI
    var displayStationName: String {
        return stationName ?? "Unknown Station"
    }
    
    var timestamp: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter.date(from: logDate) ?? Date()
    }
    
    // Create a new fuel log for local storage
    static func createLocal(stationName: String, fuelType: String, gallons: Double, pricePerGallon: Double, notes: String? = nil) -> FuelLogItem {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        return FuelLogItem(
            id: Int.random(in: 100000...999999), // Temporary local ID
            userId: 0, // Placeholder
            bikeId: nil,
            logDate: formatter.string(from: Date()),
            stationName: stationName,
            fuelType: fuelType,
            gallons: gallons,
            pricePerGallon: pricePerGallon,
            totalCost: gallons * pricePerGallon,
            odometer: nil,
            notes: notes
        )
    }
}

// FuelLogItem is the standard fuel log structure used across the app

struct FuelLogsResponse: Codable {
    let fuelLogs: [FuelLogItem]
}

struct FuelLogResponse: Codable {
    let fuelLog: FuelLogItem
}

// MARK: - Ride Recorder API Models
struct CreateRideRecordingRequest: Codable {
    let rideId: String?
    let durationSeconds: Int
    let speedSeries: [Double]
    let leanAngleSeries: [Double]?
    let accelerationSeries: [Double]?
    let brakingSeries: [Double]?
    let gpsSeries: [[Double]] // [[lat, lng, timestampSec]]
    let audioSampleUrl: String?
    let notes: String?
}

struct RideRecordingItem: Codable, Identifiable {
    let id: String
    let userId: String
    let rideId: String?
    let createdAt: String
    let durationSeconds: Int
    let speedSeries: [Double]
    let leanAngleSeries: [Double]?
    let accelerationSeries: [Double]?
    let brakingSeries: [Double]?
    let gpsSeries: [[Double]]
    let audioSampleUrl: String?
    let notes: String?
}

struct RideRecordingsResponse: Codable {
    let recordings: [RideRecordingItem]
}

struct RideRecordingResponse: Codable {
    let recording: RideRecordingItem
}

// MARK: - Safety Emergency API Models
struct EmergencyReportRequest: Codable {
    let type: String // 'crash','breakdown','medical','weather','manual'
    let severity: String // 'low','medium','high','critical'
    let location: EmergencyLocation
    let description: String?
    let automaticDetection: Bool?
    let sensorData: [String: Double]? // simple flattened metrics
    let ice: EmergencyICEPayload? // optional ICE payload for responders
}

struct EmergencyLocation: Codable {
    let latitude: Double
    let longitude: Double
}

struct EmergencyReportResponse: Codable {
    let message: String?
}

// MARK: - ICE Payload (In Case of Emergency)
struct EmergencyICEPayload: Codable {
    let bloodType: String?
    let allergies: [String]?
    let medications: [String]?
    let medicalID: String?
    let conditions: [String]?
    let emergencyNotes: String?
}

// MARK: - Ride Events API Models
struct BackendRideEvent: Codable {
    let id: Int
    let title: String
    let description: String?
    let start_time: String
    let end_time: String?
    let location: String
    let organizer_username: String
    let participant_count: Int
    let max_participants: Int?
    let is_public: Bool
    let is_participating: Int
}

struct EventsResponse: Codable {
    let events: [BackendRideEvent]
}

struct EventResponse: Codable {
    let event: BackendRideEvent
}

struct CreateEventRequest: Codable {
    let title: String
    let description: String?
    let start_time: String
    let end_time: String?
    let location: String
    let max_participants: Int?
    let is_public: Bool
}

struct CreateEventResponse: Codable {
    let message: String
    let eventId: Int
}

// MARK: - Group Music API Models
struct MusicSessionResponse: Codable {
    let session: MusicSession
}

struct MusicSession: Codable {
    let id: String
    let groupId: String
    let currentTrack: String?
    let currentArtist: String?
    let isPlaying: Bool
    let participants: [String]
}

struct ShareMusicRequest: Codable {
    let trackTitle: String
    let artist: String
    let groupId: String
}

// MARK: - Completed Rides Models

struct CompletedRideData: Identifiable {
    let id: String
    let rideType: RideType
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let distance: CLLocationDistance
    let averageSpeed: Double
    let maxSpeed: Double
    let route: [CLLocation]
    let participants: [RideParticipant]
    let safetyScore: Int
    
    var distanceInMiles: Double {
        distance * 0.000621371
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration.truncatingRemainder(dividingBy: 3600)) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
}

// Custom Codable implementation for CompletedRideData
extension CompletedRideData: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, rideType, startTime, endTime, duration, distance
        case averageSpeed, maxSpeed, route, participants, safetyScore
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(rideType.rawValue, forKey: .rideType)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(duration, forKey: .duration)
        try container.encode(distance, forKey: .distance)
        try container.encode(averageSpeed, forKey: .averageSpeed)
        try container.encode(maxSpeed, forKey: .maxSpeed)
        try container.encode(safetyScore, forKey: .safetyScore)
        try container.encode(participants, forKey: .participants)
        
        // Convert CLLocation array to coordinate pairs
        let routeCoordinates = route.map { location in
            ["lat": location.coordinate.latitude, "lng": location.coordinate.longitude]
        }
        try container.encode(routeCoordinates, forKey: .route)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        
        let rideTypeString = try container.decode(String.self, forKey: .rideType)
        guard let decodedRideType = RideType(rawValue: rideTypeString) else {
            throw DecodingError.dataCorruptedError(forKey: .rideType, in: container, debugDescription: "Invalid ride type: \(rideTypeString)")
        }
        rideType = decodedRideType
        
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        distance = try container.decode(CLLocationDistance.self, forKey: .distance)
        averageSpeed = try container.decode(Double.self, forKey: .averageSpeed)
        maxSpeed = try container.decode(Double.self, forKey: .maxSpeed)
        safetyScore = try container.decode(Int.self, forKey: .safetyScore)
        participants = try container.decode([RideParticipant].self, forKey: .participants)
        
        // Convert coordinate pairs back to CLLocation array
        let routeCoordinates = try container.decode([[String: Double]].self, forKey: .route)
        route = routeCoordinates.compactMap { coord in
            guard let lat = coord["lat"], let lng = coord["lng"] else { return nil }
            return CLLocation(latitude: lat, longitude: lng)
        }
    }
}

struct RideParticipant: Identifiable, Codable {
    let id: String
    let username: String
    let name: String
    let isCurrentUser: Bool
}

struct CompletedRidesResponse: Codable {
    let rides: [CompletedRideData]
}
