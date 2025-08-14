import SwiftUI
import MapKit

struct RideHubView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var safetyManager: SafetyManager
    @EnvironmentObject var locationSharingManager: LocationSharingManager
    @EnvironmentObject var crashDetectionManager: CrashDetectionManager
    @EnvironmentObject var weatherManager: WeatherManager
    @EnvironmentObject var voiceAssistant: VoiceAssistantManager
    @Binding var selectedTab: Int
    @State private var showingCreatePost = false
    @State private var showingRideControls = false
    @State private var showingGroupRideCreation = false
    @State private var showingGroupRideBrowse = false
    @State private var showingDestinationSearch = false
    @State private var currentRideType: RideType = .none
    @State private var newPostContent = ""
    @State private var selectedPostUsername: String?
    @State private var showingPostUserProfile = false
    @Environment(\.colorScheme) var colorScheme
    
    // Computed properties for ride data
    private var isActiveRide: Bool {
        return locationManager.rideStartTime != nil
    }
    
    private var rideTimeDisplay: String {
        if locationManager.rideStartTime != nil {
            let currentDuration = locationManager.currentRideDuration
            let hours = Int(currentDuration) / 3600
            let minutes = Int(currentDuration.truncatingRemainder(dividingBy: 3600)) / 60
            return String(format: "%d:%02d", hours, minutes)
        }
        return "00:00"
    }
    
    private var rideDistanceDisplay: String {
        let distanceInMiles = locationManager.currentRideDistance * 0.000621371
        return String(format: "%.1f", distanceInMiles)
    }
    
    private var rideSpeedDisplay: String {
        return String(format: "%.0f", locationManager.currentRideSpeed)
    }
    
    // Check if ride is active based on rideStartTime
    private var isRideActive: Bool {
        return locationManager.rideStartTime != nil
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Header with greeting and weather
                    headerSection
                    
                    // Active ride status or quick start
                    rideStatusSection
                    
                    // Essential quick actions (streamlined)
                    quickActionsSection
                    
                    // AI Ride Assistant (Premium)
                    NavigationLink(destination: AIRideAssistantView()) {
                        HStack {
                            Image(systemName: "brain.head.profile").foregroundColor(.purple)
                            Text("AI Ride Assistant")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    // Music & Voice Chat placeholders
                    HStack(spacing: 8) {
                        NavigationLink(destination: SharedMusicView()
                            .environmentObject(NowPlayingManager.shared)
                            .environmentObject(GroupRideManager.shared)
                        ) {
                            VStack(spacing: 4) {
                                Image(systemName: "music.note.list")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text("Music")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        NavigationLink(destination: GroupVoiceChatView()
                            .environmentObject(WebRTCManager.shared)
                            .environmentObject(GroupRideManager.shared)
                            .environmentObject(NetworkManager.shared)
                        ) {
                            VStack(spacing: 4) {
                                Image(systemName: "waveform")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                Text("Voice")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        NavigationLink(destination: RideEventsView()
                            .environmentObject(NetworkManager.shared)
                            .environmentObject(SocialManager.shared)
                            .environmentObject(LocationManager.shared)
                        ) {
                            VStack(spacing: 4) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.title2)
                                    .foregroundColor(.purple)
                                Text("Events")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Social feed integration
                    socialFeedSection
                    
                    // Recent activity summary
                    recentActivitySection
                }
                .padding(.horizontal)
            }
            .navigationTitle("MotoRev")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    statusIndicator
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: { showingCreatePost = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: { showingRideControls = true }) {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .refreshable {
                await refreshData()
            }
            .sheet(isPresented: $showingGroupRideBrowse) { GroupRideBrowseView() }
            .onReceive(voiceAssistant.commandPublisher) { cmd in
                switch cmd {
                case .startRide: locationManager.startRide()
                case .pauseTracking: locationManager.pauseRide()
                case .resumeTracking: locationManager.resumeRide()
                case .stopRide: locationManager.stopRide()
                case .checkWeather:
                    if let loc = locationManager.location?.coordinate {
                        WeatherManager.shared.fetchWeatherData(for: loc)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreatePost) {
            CreatePostSheet(postContent: $newPostContent)
        }
        .sheet(isPresented: $showingRideControls) {
            RideControlsSheet()
        }
        .sheet(isPresented: $showingGroupRideCreation) {
            GroupRideCreationSheet()
        }
        .sheet(isPresented: $showingPostUserProfile) {
            if let username = selectedPostUsername {
                UserProfileSheet(username: username)
            }
        }
        .sheet(isPresented: $showingDestinationSearch) {
            DestinationSearchSheet()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greetingText)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Ready to ride?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Weather widget
                weatherWidget
            }
            
            // Safety status bar
            safetyStatusBar
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Ride Status Section
    private var rideStatusSection: some View {
        Group {
            if isRideActive {
                activeRideCard
            } else {
                quickStartCard
            }
        }
    }
    
    private var activeRideCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("🏍️ Active Ride")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(locationManager.isRidePaused ? "Resume" : "Pause") {
                        if locationManager.isRidePaused {
                            locationManager.resumeRide()
                        } else {
                            locationManager.pauseRide()
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(locationManager.isRidePaused ? Color.green : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("Stop") {
                        locationManager.stopRideTracking()
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            HStack(spacing: 24) {
                VStack {
                    Text(rideTimeDisplay)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(rideDistanceDisplay) mi")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Distance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(rideSpeedDisplay) mph")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Speed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var quickStartCard: some View {
        VStack(spacing: 16) {
            Text("Start Your Ride")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Destination search bar
            Button(action: { showDestinationSearch() }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    Text("Where are you heading?")
                        .foregroundColor(.gray)
                        .font(.body)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Enhanced Ride Type Selection
            RideHubControlView(
                isRideActive: isActiveRide,
                currentRideType: getCurrentRideType(),
                onSoloRide: { startSoloRide() },
                onGroupRide: { showingGroupRideCreation = true },
                onJoinRide: { showingGroupRideBrowse = true },
                onEndRide: { locationManager.stopRideTracking() }
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Quick Actions (Streamlined)
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 8) {
                HubQuickActionButton(
                    title: "Map",
                    icon: "map.fill",
                    color: .blue
                ) {
                    selectedTab = 1 // Navigate tab
                }
                
                HubQuickActionButton(
                    title: "Garage",
                    icon: "wrench.and.screwdriver.fill",
                    color: .purple
                ) {
                    selectedTab = 2 // Garage tab
                }
                
                HubQuickActionButton(
                    title: "Fuel",
                    icon: "fuelpump.fill",
                    color: .orange
                ) {
                    selectedTab = 1 // Navigate tab (fuel finder is there)
                }
                
                HubQuickActionButton(
                    title: "Safety",
                    icon: "shield.checkered",
                    color: .red
                ) {
                    selectedTab = 3 // Safety tab
                }
            }
        }
    }
    
    // MARK: - Social Feed Section
    private var socialFeedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Community Feed")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("See All") {
                    // Navigate to full social feed - could show SocialFeedView as sheet
                    // For now, just refresh the feed to show more posts
                    socialManager.refreshSocialFeed()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if socialManager.feedPosts.isEmpty {
                Text("No recent posts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(socialManager.feedPosts.prefix(3)) { post in
                    CompactPostCard(post: post, selectedPostUsername: $selectedPostUsername, showingPostUserProfile: $showingPostUserProfile)
                }
            }
        }
    }
    
    // MARK: - Recent Activity
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            if hasRecentActivity {
                VStack(spacing: 8) {
                    if let lastRide = getLastRide() {
                        RecentActivityItem(
                            icon: "motorcycle.fill",
                            title: "Last Ride",
                            subtitle: "\(String(format: "%.1f", lastRide.distance)) miles • \(timeAgoString(lastRide.date))",
                            color: .blue
                        )
                    }
                    
                    if crashDetectionManager.isMonitoring {
                        RecentActivityItem(
                            icon: "shield.checkered",
                            title: "Safety Active",
                            subtitle: "Crash detection enabled",
                            color: .green
                        )
                    }
                    
                    if socialManager.feedPosts.count > 0 {
                        RecentActivityItem(
                            icon: "person.3.fill",
                            title: "Community",
                            subtitle: "\(socialManager.feedPosts.count) recent posts",
                            color: .purple
                        )
                    }
                }
            } else {
                Text("Start riding to see your activity here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
    }
    
    // MARK: - Helper Views
    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: crashDetectionManager.isMonitoring ? "shield.checkered" : "shield")
                .font(.caption)
                .foregroundColor(crashDetectionManager.isMonitoring ? .green : .orange)
            
            Text(crashDetectionManager.isMonitoring ? "Protected" : "Safety Off")
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(crashDetectionManager.isMonitoring ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(crashDetectionManager.isMonitoring ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var weatherWidget: some View {
        VStack(spacing: 4) {
            if let currentWeather = weatherManager.currentWeather {
                Text("\(Int(currentWeather.temperature))°")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Image(systemName: currentWeather.iconName)
                    .font(.caption)
                    .foregroundColor(weatherIconColor(for: currentWeather.conditions))
            } else {
                Text("--°")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Image(systemName: "location.slash")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            // Refresh weather when view appears
            if let location = locationManager.location {
                weatherManager.fetchWeatherData(for: location.coordinate)
            }
        }
        .onChange(of: locationManager.location) { _, newLocation in
            // Update weather when location changes
            if let location = newLocation {
                weatherManager.fetchWeatherData(for: location.coordinate)
            }
        }
    }
    
    private func weatherIconColor(for conditions: String) -> Color {
        switch conditions.lowercased() {
        case "clear": return .orange
        case "partly cloudy", "clouds": return .gray
        case "rain", "drizzle", "rain showers": return .blue
        case "snow": return .cyan
        case "thunderstorm": return .purple
        case "fog", "mist", "haze": return .gray
        default: return .gray
        }
    }
    
    private var safetyStatusBar: some View {
        HStack {
            Button(action: {
                // Navigate to safety settings
                // Could show ProfileView → Safety Center
            }) {
                Label(
                    crashDetectionManager.isMonitoring ? "Crash Detection On" : "Crash Detection Off",
                    systemImage: crashDetectionManager.isMonitoring ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
                )
                .font(.caption)
                .foregroundColor(crashDetectionManager.isMonitoring ? .green : .orange)
            }
            
            Spacer()
            
            if !safetyManager.emergencyContacts.isEmpty {
                let contactCount = safetyManager.emergencyContacts.count
                Label(contactCount == 1 ? "1 Emergency Contact" : "\(contactCount) Emergency Contacts", systemImage: "person.crop.circle.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default: return "Good Night"
        }
    }
    
    // MARK: - Helper Properties
    private var hasRecentActivity: Bool {
        return getLastRide() != nil || 
               crashDetectionManager.isMonitoring || 
               !socialManager.feedPosts.isEmpty
    }
    
    private func getLastRide() -> Ride? {
        // This would typically fetch from your data store
        return locationManager.rideHistory.last
    }
    
    // MARK: - Actions
    private func showDestinationSearch() {
        showingDestinationSearch = true
    }
    
    private func getCurrentRideType() -> RideType {
        return currentRideType
    }
    
    private func startSoloRide() {
        currentRideType = .solo
        // Start ride tracking
        locationManager.startRideTracking()
        safetyManager.startRide()
        
        // Navigate to map tab to show ride in progress
        selectedTab = 1
        
        // Create social post about the ride
        socialManager.createPost(
            content: "🏍️ Starting a solo ride! Wish me luck! #SoloRide #MotoRev",
            location: locationManager.location?.coordinate,
            rideData: RideData(
                distance: 0,
                duration: 0,
                averageSpeed: 0,
                maxSpeed: 0,
                safetyScore: 100
            )
        )
    }
    
    private func refreshData() async {
        // Refresh social feed and weather data
        socialManager.refreshSocialFeed()
    }
    
    private func timeAgoString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Shared Music UI
struct SharedMusicView: View {
    @EnvironmentObject var nowPlaying: NowPlayingManager
    @EnvironmentObject var groupRideManager: GroupRideManager
    
    var body: some View {
        List {
            Section(header: Text("Now Playing")) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(nowPlaying.currentTitle ?? "Not Playing").font(.headline)
                        Text(nowPlaying.currentArtist ?? "").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(nowPlaying.isPlaying ? "Pause" : "Play") { 
                        nowPlaying.playPause()
                    }
                }
            }
            
            if groupRideManager.isInGroupRide {
                Section(header: Text("Group Music Session")) {
                    if nowPlaying.isInGroupSession {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "person.3.fill")
                                    .foregroundColor(.green)
                                Text("Connected to group session")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                Spacer()
                                Button("Leave") {
                                    nowPlaying.leaveGroupMusicSession()
                                }
                                .foregroundColor(.red)
                            }
                            
                            if let session = nowPlaying.groupSession {
                                Text("Participants: \(session.participants.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Share your music with the group")
                                .font(.subheadline)
                            Button("Join Group Session") {
                                if let groupId = groupRideManager.currentGroupRide?.id {
                                    nowPlaying.joinGroupMusicSession(groupId: groupId)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            } else {
                Section(header: Text("Group Music")) {
                    Text("Join a group ride to share music with others.")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Shared Music")
    }
}

// Note: GroupVoiceChatView is now defined in its own file

// MARK: - Supporting Views

struct HubQuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CompactPostCard: View {
    let post: Post
    @Binding var selectedPostUsername: String?
    @Binding var showingPostUserProfile: Bool
    @EnvironmentObject var socialManager: SocialManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: {
                    selectedPostUsername = post.username
                    showingPostUserProfile = true
                }) {
                    Text(post.username)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(timeAgoString(post.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(post.content)
                .font(.subheadline)
                .lineLimit(2)
            
            HStack {
                Button(action: { 
                    // Toggle like functionality
                    socialManager.toggleLike(for: post.id)
                }) {
                    Label("\(post.likesCount)", systemImage: post.isLiked ? "heart.fill" : "heart")
                        .font(.caption)
                        .foregroundColor(post.isLiked ? .red : .secondary)
                }
                
                Spacer()
                
                Button("View") {
                    // Show full post
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func timeAgoString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct RecentActivityItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sheet Views

struct CreatePostSheet: View {
    @Binding var postContent: String
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $postContent)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding()
                
                if postContent.isEmpty {
                    Text("What's on your mind? Share your ride experiences!")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") { 
                        createPost()
                    }
                    .disabled(postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .alert("Post Created!", isPresented: $showingSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your post has been shared with the community!")
            }
        }
    }
    
    private func createPost() {
        let content = postContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !content.isEmpty else {
            return
        }
        
        print("🚀 CreatePostSheet: Creating post with content: \(content)")
        
        socialManager.createPost(
            content: content,
            image: nil,
            location: nil,
            rideData: nil
        )
        
        showingSuccess = true
        postContent = ""
    }
}



struct GroupRideCreationSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var isPrivate: Bool = false
    @State private var maxMembers: Int = 10
    @State private var isCreating: Bool = false
    @State private var creationError: String?
    @State private var createdRideId: String?
    @State private var inviteUsername: String = ""
    @State private var inviteMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    TextField("Ride name (e.g., Sunday Cruise)", text: $name)
                    TextField("Description (optional)", text: $description)
                    Toggle("Private (invite only)", isOn: $isPrivate)
                    Stepper(value: $maxMembers, in: 2...50) {
                        HStack {
                            Text("Max Members")
                            Spacer()
                            Text("\(maxMembers)")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if createdRideId != nil {
                    Section(header: Text("Invite Friends"), footer: inviteFooterView) {
                        HStack {
                            TextField("Friend's username", text: $inviteUsername)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            Button("Send") { sendInvite() }
                                .disabled(inviteUsername.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }

                if let creationError {
                    Section {
                        Text(creationError)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Group Ride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(createdRideId == nil ? "Create" : "Done") {
                        if createdRideId == nil { createRide() } else { dismiss() }
                    }
                    .disabled(isCreating || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .overlay {
                if isCreating { ProgressView("Creating...") }
            }
        }
    }

    private var inviteFooterView: some View {
        Group {
            if let inviteMessage { Text(inviteMessage).foregroundColor(.secondary) }
        }
    }

    private func createRide() {
        isCreating = true
        creationError = nil
        GroupRideManager.shared.createGroupRide(name: name.trimmingCharacters(in: .whitespaces), description: description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description.trimmingCharacters(in: .whitespaces), isPrivate: isPrivate) { result in
            isCreating = false
            switch result {
            case .success:
                createdRideId = GroupRideManager.shared.currentGroupRide?.id
            case .failure(let error):
                creationError = error.localizedDescription
            }
        }
    }

    private func sendInvite() {
        let username = inviteUsername.trimmingCharacters(in: .whitespaces)
        guard !username.isEmpty else { return }
        inviteMessage = nil
        GroupRideManager.shared.inviteUser(username) { (result: Result<Void, Error>) in
            switch result {
            case .success:
                inviteMessage = "Invitation sent to @\(username)"
                inviteUsername = ""
            case .failure(let error):
                inviteMessage = "Failed to invite: \(error.localizedDescription)"
            }
        }
    }
}

struct UserProfileSheet: View {
    let username: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Profile: \(username)")
                Spacer()
            }
            .navigationTitle(username)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DestinationSearchSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var locationManager: LocationManager
    @State private var searchText = ""
    @State private var searchResults: [SearchResult] = []
    @State private var recentDestinations: [SearchResult] = []
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search for places...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
                
                // Content
                if searchText.isEmpty {
                    // Recent destinations
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if recentDestinations.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.title)
                                    .foregroundColor(.gray)
                                Text("No recent destinations")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            ForEach(recentDestinations) { result in
                                DestinationRow(result: result) {
                                    selectDestination(result)
                                }
                            }
                        }
                    }
                } else {
                    // Search results
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Search Results")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if searchResults.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.title)
                                    .foregroundColor(.gray)
                                Text("No results found")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            ForEach(searchResults) { result in
                                DestinationRow(result: result) {
                                    selectDestination(result)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Where to?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            loadRecentDestinations()
        }
    }
    
    private func performSearch() {
        // For now, simulate search results
        searchResults = [
            SearchResult(id: "1", name: "Starbucks", address: "123 Main St", category: "Coffee"),
            SearchResult(id: "2", name: "Central Park", address: "New York, NY", category: "Park"),
            SearchResult(id: "3", name: "Highway 1", address: "California Coast", category: "Scenic Route")
        ].filter { result in
            result.name.localizedCaseInsensitiveContains(searchText) ||
            result.address.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func loadRecentDestinations() {
        // For now, show sample recent destinations
        recentDestinations = [
            SearchResult(id: "r1", name: "Home", address: "Your home address", category: "Saved"),
            SearchResult(id: "r2", name: "Work", address: "Your work address", category: "Saved"),
            SearchResult(id: "r3", name: "Gas Station", address: "Shell on Oak Ave", category: "Recent")
        ]
    }
    
    private func selectDestination(_ destination: SearchResult) {
        print("🎯 Selected destination: \(destination.name)")
        
        // Convert address to coordinate using geocoding
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(destination.address) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first,
                   let coordinate = placemark.location?.coordinate {
                    // Set the destination in LocationManager
                    self.locationManager.selectedDestination = destination.name
                    self.locationManager.selectedDestinationCoordinate = coordinate
                    
                    // Calculate route to destination
                    self.locationManager.calculateRoute(to: coordinate)
                    
                    print("📍 Route calculated to \(destination.name) at \(coordinate)")
                } else {
                    print("❌ Could not geocode address: \(destination.address)")
                }
                self.dismiss()
            }
        }
    }
}

struct DestinationRow: View {
    let result: SearchResult
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: iconForCategory(result.category))
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(result.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "coffee": return "cup.and.saucer.fill"
        case "park": return "tree.fill"
        case "scenic route": return "road.lanes"
        case "saved": return "house.fill"
        case "recent": return "clock.fill"
        default: return "mappin.circle.fill"
        }
    }
}

// MARK: - Enhanced Ride Hub Control

struct RideHubControlView: View {
    let isRideActive: Bool
    let currentRideType: RideType
    let onSoloRide: () -> Void
    let onGroupRide: () -> Void
    let onJoinRide: () -> Void
    let onEndRide: () -> Void
    
    var body: some View {
        if isRideActive {
            // Active ride display
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Ride")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Image(systemName: currentRideType.icon)
                                .foregroundColor(currentRideType.color)
                            Text(currentRideType.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button("End Ride") {
                        onEndRide()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                
                // Quick ride stats would go here
                HStack(spacing: 24) {
                    VStack {
                        Text("--:--")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("0.0 mi")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Distance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("0 mph")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Speed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .padding()
            .background(currentRideType.color.opacity(0.1))
            .cornerRadius(16)
        } else {
            // Start ride options
            VStack(spacing: 12) {
                HStack {
                    Text("Start Your Ride")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Image(systemName: "figure.motorcycle")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                HStack(spacing: 8) {
                    // Solo Ride
                    RideTypeButton(
                        icon: "person.fill",
                        title: "Solo",
                        subtitle: "Independent ride",
                        color: .green,
                        action: onSoloRide
                    )
                    
                    // Group Ride
                    RideTypeButton(
                        icon: "person.3.fill",
                        title: "Group",
                        subtitle: "Lead others",
                        color: .purple,
                        action: onGroupRide
                    )
                    
                    // Join Ride
                    RideTypeButton(
                        icon: "person.2.fill",
                        title: "Join",
                        subtitle: "Find groups",
                        color: .orange,
                        action: onJoinRide
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
}

struct RideTypeButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SearchResult: Identifiable {
    let id: String
    let name: String
    let address: String
    let category: String
}