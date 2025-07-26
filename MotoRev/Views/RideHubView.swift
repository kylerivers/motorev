import SwiftUI
import MapKit

struct RideHubView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var safetyManager: SafetyManager
    @EnvironmentObject var locationSharingManager: LocationSharingManager
    @EnvironmentObject var crashDetectionManager: CrashDetectionManager
    @EnvironmentObject var weatherManager: WeatherManager
    @Binding var selectedTab: Int
    @State private var showingCreatePost = false
    @State private var showingRideControls = false
    @State private var showingGroupRideCreation = false
    @State private var showingDestinationSearch = false
    @State private var newPostContent = ""
    @State private var selectedPostUsername: String?
    @State private var showingPostUserProfile = false
    @Environment(\.colorScheme) var colorScheme
    
    // Computed properties for ride data
    private var rideTimeDisplay: String {
        if let startTime = locationManager.rideStartTime {
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
            
            HStack(spacing: 12) {
                Button(action: { startSoloRide() }) {
                    Label("Solo Ride", systemImage: "person.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button(action: { showingGroupRideCreation = true }) {
                    Label("Group Ride", systemImage: "person.3.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
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
            
            HStack(spacing: 12) {
                HubQuickActionButton(
                    title: "Navigate",
                    icon: "map.fill",
                    color: .blue
                ) {
                    selectedTab = 1 // Navigate tab
                }
                
                HubQuickActionButton(
                    title: "Garage",
                    icon: "car.circle.fill",
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
            Circle()
                .fill(crashDetectionManager.isMonitoring ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            
            Text(crashDetectionManager.isMonitoring ? "Protected" : "Safety Off")
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    private var weatherWidget: some View {
        VStack(spacing: 4) {
            Text("72°")
                .font(.title2)
                .fontWeight(.semibold)
            
            Image(systemName: "sun.max.fill")
                .font(.caption)
                .foregroundColor(.orange)
        }
    }
    
    private var safetyStatusBar: some View {
        HStack {
            Label(
                crashDetectionManager.isMonitoring ? "Safety Active" : "Safety Inactive",
                systemImage: crashDetectionManager.isMonitoring ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
            )
            .font(.caption)
            .foregroundColor(crashDetectionManager.isMonitoring ? .green : .orange)
            
            Spacer()
            
            if !safetyManager.emergencyContacts.isEmpty {
                Label("\(safetyManager.emergencyContacts.count) contacts", systemImage: "person.crop.circle.fill")
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
    
    private func startSoloRide() {
        // Start ride tracking
        locationManager.startRideTracking()
        safetyManager.startRide()
        
        // Navigate to map tab to show ride in progress
        selectedTab = 1
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

// MARK: - Supporting Views

struct HubQuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
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
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Create Group Ride")
                Spacer()
            }
            .navigationTitle("Group Ride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") { dismiss() }
                }
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

struct SearchResult: Identifiable {
    let id: String
    let name: String
    let address: String
    let category: String
}