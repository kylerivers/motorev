import SwiftUI
import CoreLocation
import Combine // Added for Combine

struct SocialFeedView: View {
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var showingCreatePost = false
    @State private var newPostContent = ""
    @State private var refreshing = false
    @State private var showingSearch = false
    @State private var selectedPostUsername: String?
    @State private var showingPostUserProfile = false
    
    var body: some View {
        NavigationView {
            RefreshableScrollView(onRefresh: refreshFeed) {
                LazyVStack(spacing: 0) {
                    // Stories/Status bar
                    StoriesView()
                        .padding(.vertical, 8)
                    
                    // Posts
                    ForEach(socialManager.feedPosts) { post in
                        PostView(post: post, selectedPostUsername: $selectedPostUsername, showingPostUserProfile: $showingPostUserProfile)
                            .padding(.bottom, 8)
                    }
                    
                    if socialManager.feedPosts.isEmpty {
                        EmptyFeedView()
                    }
                }
            }
            .navigationTitle("MotoRev")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSearch = true }) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreatePost = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                }
            }
            .sheet(isPresented: $showingCreatePost) {
                CreatePostView()
            }
            .sheet(isPresented: $showingSearch) {
                TemporarySearchView()
            }
            .sheet(isPresented: $showingPostUserProfile) {
                if let username = selectedPostUsername {
                    UsernameProfileView(username: username)
                }
            }
            .onAppear {
                // Force authentication and feed refresh when view appears
                socialManager.forceAuthenticationAndRefresh()
            }
        }
    }
    
    private func refreshFeed() {
        refreshing = true
        socialManager.forceAuthenticationAndRefresh()
        
        // Reset refreshing state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            refreshing = false
        }
    }
}

struct StoriesView: View {
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var showingCreateStory = false
    @State private var selectedStoryGroup: StoryGroup?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Add Story button
                Button(action: { showingCreateStory = true }) {
                    VStack {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                        
                        Text("Your Story")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Story groups from followed users
                ForEach(socialManager.storyGroups, id: \.id) { (storyGroup: StoryGroup) in
                    Button(action: { selectedStoryGroup = storyGroup }) {
                        VStack {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: storyGroup.hasUnviewedStories ? [.red, .orange] : [.gray, .gray.opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 64, height: 64)
                                
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 58, height: 58)
                                
                                // Live indicator removed - Story model doesn't have isLive property
                                
                                Image(systemName: "person.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.gray)
                            }
                            
                            Text(storyGroup.username)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                }
                
                // Live riders nearby (for backwards compatibility)
                ForEach(locationManager.nearbyRiders) { rider in
                    if rider.isRiding {
                        VStack {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 64, height: 64)
                                
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 58, height: 58)
                                
                                // Live indicator
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 12, height: 12)
                                    .offset(x: 22, y: -22)
                                
                                Image(systemName: "person.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.gray)
                            }
                            
                            Text(rider.name)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showingCreateStory) {
            CreateStoryView()
        }
        .fullScreenCover(item: $selectedStoryGroup) { storyGroup in
            StoryViewerView(storyGroup: storyGroup)
        }
    }
}

struct PostView: View {
    let post: Post
    @EnvironmentObject var socialManager: SocialManager
    @State private var showingComments = false
    @State private var showingShareSheet = false
    @State private var shareCaption = ""
    @Binding var selectedPostUsername: String?
    @Binding var showingPostUserProfile: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Profile image
                Image(systemName: "person.circle.fill")
                    .font(.title)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Button(action: {
                            selectedPostUsername = post.username
                            showingPostUserProfile = true
                        }) {
                            Text(post.username)
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Verification badge removed - not available in Post model
                    }
                    
                    // Location removed - Post model doesn't have location property
                }
                
                Spacer()
                
                Text(timeAgo(from: post.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Content
            Text(post.content)
                .font(.body)
                .padding(.horizontal)
            
            // Ride data if available
            if let rideData = post.rideData {
                RideDataView(rideData: rideData)
                    .padding(.horizontal)
            }
            
            // Action buttons
            HStack(spacing: 24) {
                // Like button
                Button(action: {
                    socialManager.likePost(post)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: post.isLiked ? "heart.fill" : "heart")
                            .foregroundColor(post.isLiked ? .red : .gray)
                        Text("\(post.likesCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Comment button
                Button(action: {
                    showingComments = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right.fill")
                            .foregroundColor(.blue)
                        Text("\(post.commentsCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Share button
                Button(action: {
                    showingShareSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.right.fill")
                            .foregroundColor(.green)
                        Text("Share")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showingComments) {
            CommentsView(post: post)
        }
        .sheet(isPresented: $showingShareSheet) {
            SharePostView(post: post, caption: $shareCaption) {
                socialManager.sharePost(post, caption: shareCaption)
                showingShareSheet = false
                shareCaption = ""
            }
        }
    }
    
    private func formatLocation(_ location: CLLocationCoordinate2D) -> String {
        // Use reverse geocoding to get human-readable location
        // let geocoder = CLGeocoder() // TODO: Implement async reverse geocoding
        let locationObj = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        // For now, return a formatted location based on coordinates
        // In production, you'd cache the reverse geocoding results
        return formatCoordinatesToReadableLocation(locationObj.coordinate)
    }
    
    private func formatCoordinatesToReadableLocation(_ coordinate: CLLocationCoordinate2D) -> String {
        // Simple mapping of known coordinates to readable locations
        // In real app, this would use CLGeocoder.reverseGeocodeLocation
        
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        
        // Florida area (around Tampa/St. Petersburg)
        if lat > 27.0 && lat < 28.5 && lon > -83.0 && lon < -82.0 {
            return "in Seminole, FL"
        } else if lat > 27.5 && lat < 28.0 && lon > -82.8 && lon < -82.3 {
            return "in Tampa, FL"
        } else if lat > 27.7 && lat < 28.1 && lon > -82.9 && lon < -82.6 {
            return "in St. Petersburg, FL"
        }
        
        // San Francisco Bay Area
        else if lat > 37.7 && lat < 37.8 && lon > -122.5 && lon < -122.3 {
            return "in San Francisco, CA"
        }
        
        // Fallback to general region
        else if lat > 25.0 && lat < 30.0 && lon > -85.0 && lon < -80.0 {
            return "in Florida"
        } else if lat > 37.0 && lat < 38.0 && lon > -123.0 && lon < -121.0 {
            return "in California"
        }
        
        // Final fallback to state/region
        return "near \(String(format: "%.1f", lat))°N, \(String(format: "%.1f", abs(lon)))°W"
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct RideDataView: View {
    let rideData: RideData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "motorcycle")
                    .foregroundColor(.red)
                Text("Ride Summary")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Distance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", rideData.distance * 0.000621371)) mi")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDuration(rideData.duration))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading) {
                    Text("Avg Speed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.0f", rideData.averageSpeed)) mph")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var content = ""
    @State private var includeLocation = false
    @State private var selectedRideData: RideData?
    @State private var showingRideSelector = false
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Adaptive background for dark mode
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // User info section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.gray)
                                
                                VStack(alignment: .leading) {
                                    Text(socialManager.currentUser?.username ?? "User")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Share your ride")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            
                            // Content input
                            TextField("What's on your mind?", text: $content, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(5...10)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                            
                            // Image preview
                            if let image = selectedImage {
                                HStack {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipped()
                                        .cornerRadius(8)
                                    
                                    Text("Photo attached")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button("Remove") {
                                        selectedImage = nil
                                    }
                                    .font(.caption)
                                    .foregroundColor(.red)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        
                        // Options section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Options")
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 12) {
                                // Add photo option
                                HStack {
                                    Image(systemName: "photo.fill")
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    Text("Add photo")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Button(action: { showingImagePicker = true }) {
                                        HStack {
                                            if selectedImage != nil {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                            }
                                            Text(selectedImage != nil ? "Photo Added" : "Select Photo")
                                                .foregroundColor(.blue)
                                                .font(.subheadline)
                                        }
                                    }
                                }
                                
                                Divider()
                                
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.red)
                                        .frame(width: 24)
                                    Text("Include location")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Toggle("", isOn: $includeLocation)
                                }
                                
                                if !locationManager.rideHistory.isEmpty {
                                    Divider()
                                    HStack {
                                        Image(systemName: "motorcycle")
                                            .foregroundColor(.orange)
                                            .frame(width: 24)
                                        Text("Attach ride data")
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Button(action: { showingRideSelector = true }) {
                                            Text(selectedRideData != nil ? "✓ Selected" : "Select Ride")
                                                .foregroundColor(.orange)
                                                .font(.subheadline)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        
                        Spacer(minLength: 50)
                    }
                    .padding()
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        createPost()
                    }
                    .disabled(content.isEmpty && selectedImage == nil)
                    .foregroundColor((content.isEmpty && selectedImage == nil) ? .gray : .red)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingRideSelector) {
                RideSelectorView(selectedRide: $selectedRideData)
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerView(selectedImage: $selectedImage)
            }
        }
    }
    
    private func createPost() {
        print("🔄 CreatePostView: Post button tapped")
        print("📝 Content: '\(content)'")
        print("📸 Selected image: \(selectedImage != nil)")
        print("📍 Include location: \(includeLocation)")
        
        let location = includeLocation ? locationManager.location?.coordinate : nil
        
        if location != nil {
            print("📍 Location: \(location!.latitude), \(location!.longitude)")
        }
        
        // Validate input
        if content.isEmpty && selectedImage == nil {
            print("❌ CreatePostView: No content or image to post")
            return
        }
        
        print("🚀 CreatePostView: Calling socialManager.createPost...")
        socialManager.createPost(
            content: content,
            image: selectedImage,
            location: location,
            rideData: selectedRideData
        )
        
        print("✅ CreatePostView: Post creation initiated, dismissing view")
        dismiss()
    }
}

// MARK: - Comments View
struct CommentsView: View {
    let post: Post
    @EnvironmentObject var socialManager: SocialManager
    @State private var comments: [Comment] = []
    @State private var newComment = ""
    @State private var isLoading = true
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            VStack {
                // Post preview
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(post.username)
                            .font(.headline)
                        Spacer()
                        Text(timeAgo(from: post.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(post.content)
                        .font(.body)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .padding(.horizontal)
                
                Divider()
                
                if isLoading {
                    ProgressView("Loading comments...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Comments list
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(comments) { comment in
                                CommentRowView(comment: comment)
                                    .padding(.horizontal)
                            }
                            
                            if comments.isEmpty {
                                Text("No comments yet. Be the first to comment!")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .padding(.vertical)
                    }
                }
                
                // Add comment section
                HStack {
                    TextField("Add a comment...", text: $newComment)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Post") {
                        addComment()
                    }
                    .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadComments()
        }
    }
    
    private func loadComments() {
        isLoading = true
        socialManager.getComments(for: post)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        print("Error loading comments: \(error)")
                        isLoading = false
                    }
                },
                receiveValue: { loadedComments in
                    comments = loadedComments
                    isLoading = false
                }
            )
            .store(in: &cancellables)
    }
    
    private func addComment() {
        let commentText = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !commentText.isEmpty else { return }
        
        newComment = ""
        
        socialManager.commentOnPost(post, content: commentText)
        
        // Reload comments after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            loadComments()
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct CommentRowView: View {
    let comment: Comment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.username)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(timeAgo(from: comment.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(comment.content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            
            if comment.likesCount > 0 {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("\(comment.likesCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Share Post View
struct SharePostView: View {
    let post: Post
    @Binding var caption: String
    let onShare: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Original post preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sharing post from @\(post.username)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(post.username)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text(timeAgo(from: post.timestamp))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(post.content)
                            .font(.body)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
                
                // Caption input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add your thoughts (optional)")
                        .font(.headline)
                    
                    TextField("What do you think about this post?", text: $caption, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(3...6)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Share Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        onShare()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct RideSelectorView: View {
    @Binding var selectedRide: RideData?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        NavigationView {
            List(locationManager.rideHistory, id: \.id) { ride in
                Button(action: {
                    // Convert Ride to RideData
                    selectedRide = RideData(
                        distance: ride.distance,
                        duration: ride.duration,
                        averageSpeed: ride.averageSpeed,
                        maxSpeed: ride.maxSpeed,
                        safetyScore: ride.safetyScore
                    )
                    dismiss()
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ride.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.headline)
                        Text("\(String(format: "%.1f", ride.distance * 0.000621371)) miles")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
            }
            .navigationTitle("Select Ride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "motorcycle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Welcome to MotoRev!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Start following riders and share your adventures to see posts here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 60)
    }
}

struct RefreshableScrollView<Content: View>: View {
    let onRefresh: () -> Void
    let content: Content
    
    init(onRefresh: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onRefresh = onRefresh
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            content
        }
        .refreshable {
            onRefresh()
        }
    }
}

// MARK: - Story Creation View
struct CreateStoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var storyText = ""
    @State private var backgroundColor = Color.black
    @State private var textColor = Color.white
    @State private var includeLocation = false
    @State private var includeRideData = false
    @State private var selectedRideData: RideData?
    @State private var isLiveStory = false
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    
    private let backgroundColors: [Color] = [
        .black, .red, .blue, .green, .orange, .purple, .pink
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background - use image if selected, otherwise color
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                        .overlay(
                            Rectangle()
                                .fill(Color.black.opacity(0.3))
                                .ignoresSafeArea()
                        )
                } else {
                    backgroundColor
                        .ignoresSafeArea()
                }
                
                VStack(spacing: 20) {
                    Spacer()
                    
                    // Text input
                    TextField("Add to your story...", text: $storyText, axis: .vertical)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(5...8)
                        .padding()
                    
                    Spacer()
                    
                    // Options panel
                    VStack(spacing: 16) {
                        // Photo and background options
                        HStack(spacing: 16) {
                            // Add photo button
                            Button(action: { showingImagePicker = true }) {
                                VStack {
                                    Image(systemName: selectedImage != nil ? "photo.fill" : "photo")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    Text(selectedImage != nil ? "Change" : "Photo")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .frame(width: 60, height: 60)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(8)
                            }
                            
                            // Background color picker (only if no image)
                            if selectedImage == nil {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(backgroundColors, id: \.self) { color in
                                            Circle()
                                                .fill(color)
                                                .frame(width: 40, height: 40)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: backgroundColor == color ? 3 : 0)
                                                )
                                                .onTapGesture {
                                                    backgroundColor = color
                                                    if color == .black || color == .blue {
                                                        textColor = .white
                                                    } else {
                                                        textColor = .black
                                                    }
                                                }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        // Toggle options
                        VStack(spacing: 8) {
                            Toggle("Include Location", isOn: $includeLocation)
                                .foregroundColor(.white)
                            
                            if !locationManager.rideHistory.isEmpty {
                                Toggle("Include Ride Data", isOn: $includeRideData)
                                    .foregroundColor(.white)
                            }
                            
                            if locationManager.rideStartTime != nil {
                                Toggle("Live Story (active ride)", isOn: $isLiveStory)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Create Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        createStory()
                    }
                    .disabled(storyText.isEmpty && selectedImage == nil)
                    .foregroundColor((storyText.isEmpty && selectedImage == nil) ? .gray : .white)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerView(selectedImage: $selectedImage)
            }
        }
    }
    
    private func createStory() {
        // Upload image to server and get URL
        var imageUrl: String? = nil
        if let image = selectedImage {
            // Convert image to base64 for upload
            if let imageData = image.jpegData(compressionQuality: 0.7) {
                let base64String = imageData.base64EncodedString()
                imageUrl = base64String
            }
        }
        
        socialManager.createStory(
            content: storyText.isEmpty ? nil : storyText,
            mediaUrl: imageUrl
        )
        
        dismiss()
    }
}

// MARK: - Story Viewer
struct StoryViewerView: View {
    let storyGroup: StoryGroup
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var socialManager: SocialManager
    @State private var currentStoryIndex = 0
    @State private var progress: Double = 0
    @State private var timer: Timer?
    
    private let storyDuration: Double = 5.0 // 5 seconds per story
    
    var currentStory: Story? {
        guard currentStoryIndex < storyGroup.stories.count else { return nil }
        return storyGroup.stories[currentStoryIndex]
    }
    
    var body: some View {
        ZStack {
            if let story = currentStory {
                // Background
                Color.blue
                    .ignoresSafeArea()
                
                VStack {
                    // Progress bars
                    HStack(spacing: 2) {
                        ForEach(0..<storyGroup.stories.count, id: \.self) { index in
                            ProgressView(value: progressForStory(at: index))
                                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                .scaleEffect(y: 0.5)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Header
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading) {
                            Text(story.username)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(timeAgo(from: story.timestamp))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Story content
                    VStack(spacing: 16) {
                        Text(story.content)
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // Location removed - Story model doesn't have location property
                        
                        // Ride data removed - Story model doesn't have rideData property
                        
                        // Live indicator removed - Story model doesn't have isLive property
                    }
                    
                    Spacer()
                }
                
                // Tap areas for navigation
                HStack(spacing: 0) {
                    // Previous story
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            previousStory()
                        }
                    
                    // Next story
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            nextStory()
                        }
                }
            }
        }
        .onAppear {
            startTimer()
            if let story = currentStory {
                socialManager.viewStory(story)
            }
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func progressForStory(at index: Int) -> Double {
        if index < currentStoryIndex {
            return 1.0
        } else if index == currentStoryIndex {
            return progress
        } else {
            return 0.0
        }
    }
    
    private func startTimer() {
        stopTimer()
        progress = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            progress += 0.1 / storyDuration
            if progress >= 1.0 {
                nextStory()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func nextStory() {
        if currentStoryIndex < storyGroup.stories.count - 1 {
            currentStoryIndex += 1
            startTimer()
            if let story = currentStory {
                socialManager.viewStory(story)
            }
        } else {
            dismiss()
        }
    }
    
    private func previousStory() {
        if currentStoryIndex > 0 {
            currentStoryIndex -= 1
            startTimer()
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Color Extensions
extension Color {
    static let adaptiveBackground = Color(.systemBackground)
    static let adaptiveSecondaryBackground = Color(.secondarySystemBackground)
}

// MARK: - Image Picker View
struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// Temporary SearchView until the main SearchView compilation issue is resolved
struct TemporarySearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var socialManager: SocialManager
    @State private var searchText = ""
    @State private var searchResults: [SearchUser] = []
    @State private var isSearching = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var searchTimer: Timer?
    @State private var selectedUser: SearchUser?
    @State private var showingUserProfile = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search users...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onChange(of: searchText) { oldValue, newValue in
                                // Real-time search with debouncing
                                searchTimer?.invalidate()
                                searchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                    performSearch()
                                }
                            }
                            .onSubmit {
                                searchTimer?.invalidate()
                                performSearch()
                            }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    if !searchText.isEmpty {
                        Button("Cancel") {
                            searchText = ""
                            searchResults = []
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    Text("No users found")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(searchResults) { user in
                        Button(action: {
                            // Navigate to user profile
                            showUserProfile(user)
                        }) {
                            HStack {
                                AsyncImage(url: URL(string: user.profilePicture ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                
                                VStack(alignment: .leading) {
                                    Text(user.username)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    if let firstName = user.firstName, let lastName = user.lastName {
                                        Text("\(firstName) \(lastName)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    if let motorcycleMake = user.motorcycleMake {
                                        Text("🏍️ \(motorcycleMake)")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingUserProfile) {
            if let user = selectedUser {
                UserProfileView(user: user)
            }
        }
    }
    
    private func showUserProfile(_ user: SearchUser) {
        selectedUser = user
        showingUserProfile = true
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        socialManager.searchUsers(query: searchText)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isSearching = false
                    if case .failure(let error) = completion {
                        print("Search error: \(error)")
                    }
                },
                receiveValue: { users in
                    searchResults = users
                }
            )
            .store(in: &cancellables)
    }
}

// User profile view for viewing other users' profiles
struct UserProfileView: View {
    let user: SearchUser
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Profile header
                VStack(spacing: 15) {
                    AsyncImage(url: URL(string: user.profilePicture ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    
                    VStack(spacing: 8) {
                        Text(user.username)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let firstName = user.firstName, let lastName = user.lastName {
                            Text("\(firstName) \(lastName)")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let motorcycleMake = user.motorcycleMake, let motorcycleModel = user.motorcycleModel {
                            HStack {
                                Image(systemName: "car.circle")
                                    .foregroundColor(.blue)
                                Text("\(motorcycleMake) \(motorcycleModel)")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        } else if let motorcycleMake = user.motorcycleMake {
                            HStack {
                                Image(systemName: "car.circle")
                                    .foregroundColor(.blue)
                                Text(motorcycleMake)
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .padding()
                
                // Stats section
                if let safetyScore = user.safetyScore, let totalRides = user.totalRides {
                    VStack(spacing: 15) {
                        Text("Stats")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 20) {
                            VStack {
                                Text("\(safetyScore)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                Text("Safety Score")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Text("\(totalRides)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                Text("Total Rides")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Username-based profile view for users clicked from posts
struct UsernameProfileView: View {
    let username: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var socialManager: SocialManager
    @State private var userProfile: BackendUser?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Loading profile...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        
                        Text("Profile not found")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let user = userProfile {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Profile header
                            VStack(spacing: 15) {
                                // Profile picture placeholder since BackendUser doesn't have profilePictureUrl
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Text(user.username.prefix(1).uppercased())
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("@\(user.username)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                        
                                        if user.isVerified ?? false {
                                            Image(systemName: "checkmark.seal.fill")
                                                .foregroundColor(.blue)
                                                .font(.title3)
                                        }
                                    }
                                    
                                    if let firstName = user.firstName, let lastName = user.lastName {
                                        Text("\(firstName) \(lastName)")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if let motorcycleMake = user.motorcycleMake, let motorcycleModel = user.motorcycleModel {
                                        HStack {
                                            Image(systemName: "car.circle")
                                                .foregroundColor(.blue)
                                            Text("\(motorcycleMake) \(motorcycleModel)")
                                                .font(.subheadline)
                                                .foregroundColor(.blue)
                                        }
                                    } else if let motorcycleMake = user.motorcycleMake {
                                        HStack {
                                            Image(systemName: "car.circle")
                                                .foregroundColor(.blue)
                                            Text(motorcycleMake)
                                                .font(.subheadline)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    
                                    if let bio = user.bio, !bio.isEmpty {
                                        Text(bio)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                    }
                                }
                            }
                            .padding()
                            
                            // Stats section
                            VStack(spacing: 16) {
                                HStack(spacing: 40) {
                                    VStack {
                                        Text("\(user.safetyScore ?? 100)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.green)
                                        Text("Safety Score")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    VStack {
                                        Text("\(user.totalMiles?.formatted(.number.precision(.fractionLength(0))) ?? "0")")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.orange)
                                        Text("Total Miles")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    VStack {
                                        Text("\(user.totalRides ?? 0)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                        Text("Total Rides")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                HStack(spacing: 40) {
                                    VStack {
                                        Text("\(user.postsCount ?? 0)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.purple)
                                        Text("Posts")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    VStack {
                                        Text("\(user.followersCount ?? 0)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.red)
                                        Text("Followers")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    VStack {
                                        Text("\(user.followingCount ?? 0)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.teal)
                                        Text("Following")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadUserProfile()
            }
        }
    }
    
    private func loadUserProfile() {
        isLoading = true
        errorMessage = nil
        
        socialManager.getUserProfile(username: username)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        errorMessage = "Unable to load profile for @\(username)"
                        print("Failed to load user profile: \(error)")
                    }
                },
                receiveValue: { user in
                    userProfile = user
                }
            )
            .store(in: &socialManager.cancellables)
    }
}

#Preview {
    SocialFeedView()
        .environmentObject(SocialManager.shared)
        .environmentObject(LocationManager.shared)
} 