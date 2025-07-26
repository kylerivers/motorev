import SwiftUI
import Combine

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var socialManager: SocialManager
    @State private var searchText = ""
    @State private var selectedCategory = SearchCategory.all
    @State private var isSearching = false
    @State private var cancellables = Set<AnyCancellable>()
    
    // Search results
    @State private var searchUsers: [SearchUser] = []
    @State private var searchPosts: [Post] = []
    @State private var searchStories: [SearchStory] = []
    @State private var searchPacks: [SearchPack] = []
    @State private var searchRides: [SearchRide] = []
    @State private var allResults: SearchResults?
    
    // Real-time suggestions
    @State private var suggestions: [SearchSuggestion] = []
    @State private var showingSuggestions = false
    
    enum SearchCategory: String, CaseIterable {
        case all = "All"
        case users = "Users"
        case posts = "Posts"
        case stories = "Stories"
        case packs = "Packs"
        case rides = "Rides"
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search MotoRev...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onSubmit {
                                performSearch()
                                showingSuggestions = false
                            }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    if !searchText.isEmpty {
                        Button("Cancel") {
                            searchText = ""
                            clearResults()
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                // Category picker
                Picker("Category", selection: $selectedCategory) {
                    ForEach(SearchCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onChange(of: selectedCategory) { _, _ in
                    if !searchText.isEmpty {
                        performSearch()
                    }
                }
                
                // Search suggestions or results
                if showingSuggestions && !suggestions.isEmpty && !searchText.isEmpty {
                    SearchSuggestionsView(
                        suggestions: suggestions,
                        onSuggestionTap: { suggestion in
                            searchText = suggestion.username
                            showingSuggestions = false
                            performSearch()
                        }
                    )
                } else if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchText.isEmpty {
                    EmptySearchView()
                } else {
                    SearchResultsView(
                        category: selectedCategory,
                        users: searchUsers,
                        posts: searchPosts,
                        stories: searchStories,
                        packs: searchPacks,
                        rides: searchRides,
                        allResults: allResults
                    )
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
            .onChange(of: searchText) { _, newValue in
                if newValue.count >= 1 {
                    // Show suggestions for real-time typing
                    showingSuggestions = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if searchText == newValue && !newValue.isEmpty {
                            loadSuggestions()
                        }
                    }
                    
                    // Debounce full search
                    if newValue.count >= 2 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            if searchText == newValue && !newValue.isEmpty {
                                showingSuggestions = false
                                performSearch()
                            }
                        }
                    }
                } else if newValue.isEmpty {
                    showingSuggestions = false
                    clearResults()
                    suggestions = []
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty, searchText.count >= 2 else { return }
        
        isSearching = true
        clearResults()
        
        switch selectedCategory {
        case .all:
            searchAll()
        case .users:
            searchUsersOnly()
        case .posts:
            searchPostsOnly()
        case .stories:
            searchStoriesOnly()
        case .packs:
            searchPacksOnly()
        case .rides:
            searchRidesOnly()
        }
    }
    
    private func searchAll() {
        socialManager.searchAll(query: searchText)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isSearching = false
                    if case .failure(let error) = completion {
                        print("Search error: \(error)")
                    }
                },
                receiveValue: { results in
                    allResults = results
                    isSearching = false
                }
            )
            .store(in: &cancellables)
    }
    
    private func searchUsersOnly() {
        socialManager.searchUsers(query: searchText)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isSearching = false
                    if case .failure(let error) = completion {
                        print("Search users error: \(error)")
                    }
                },
                receiveValue: { users in
                    searchUsers = users
                    isSearching = false
                }
            )
            .store(in: &cancellables)
    }
    
    private func searchPostsOnly() {
        socialManager.searchPosts(query: searchText)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isSearching = false
                    if case .failure(let error) = completion {
                        print("Search posts error: \(error)")
                    }
                },
                receiveValue: { posts in
                    searchPosts = posts
                    isSearching = false
                }
            )
            .store(in: &cancellables)
    }
    
    private func searchStoriesOnly() {
        socialManager.searchStories(query: searchText)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isSearching = false
                    if case .failure(let error) = completion {
                        print("Search stories error: \(error)")
                    }
                },
                receiveValue: { stories in
                    searchStories = stories
                    isSearching = false
                }
            )
            .store(in: &cancellables)
    }
    
    private func searchPacksOnly() {
        socialManager.searchPacks(query: searchText)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isSearching = false
                    if case .failure(let error) = completion {
                        print("Search packs error: \(error)")
                    }
                },
                receiveValue: { packs in
                    searchPacks = packs
                    isSearching = false
                }
            )
            .store(in: &cancellables)
    }
    
    private func searchRidesOnly() {
        socialManager.searchRides(query: searchText)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isSearching = false
                    if case .failure(let error) = completion {
                        print("Search rides error: \(error)")
                    }
                },
                receiveValue: { rides in
                    searchRides = rides
                    isSearching = false
                }
            )
            .store(in: &cancellables)
    }
    
    private func clearResults() {
        searchUsers = []
        searchPosts = []
        searchStories = []
        searchPacks = []
        searchRides = []
        allResults = nil
        suggestions = []
        showingSuggestions = false
    }
    
    private func loadSuggestions() {
        guard !searchText.isEmpty else { 
            suggestions = []
            return 
        }
        
        socialManager.getSearchSuggestions(query: searchText)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Search suggestions error: \(error)")
                    }
                },
                receiveValue: { [self] newSuggestions in
                    // Only update if search text hasn't changed
                    if !searchText.isEmpty {
                        suggestions = newSuggestions
                    }
                }
            )
            .store(in: &cancellables)
    }
}

struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Search MotoRev")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Find riders, posts, stories, packs, and rides")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SearchResultsView: View {
    let category: SearchView.SearchCategory
    let users: [SearchUser]
    let posts: [Post]
    let stories: [SearchStory]
    let packs: [SearchPack]
    let rides: [SearchRide]
    let allResults: SearchResults?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                switch category {
                case .all:
                    if let results = allResults {
                        AllSearchResultsView(results: results)
                    } else {
                        EmptyResultsView()
                    }
                case .users:
                    if users.isEmpty {
                        EmptyResultsView()
                    } else {
                        ForEach(users) { user in
                            SearchUserRow(user: user)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        }
                    }
                case .posts:
                    if posts.isEmpty {
                        EmptyResultsView()
                    } else {
                        ForEach(posts) { post in
                            SearchPostRow(post: post)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        }
                    }
                case .stories:
                    if stories.isEmpty {
                        EmptyResultsView()
                    } else {
                        ForEach(stories) { story in
                            SearchStoryRow(story: story)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        }
                    }
                case .packs:
                    if packs.isEmpty {
                        EmptyResultsView()
                    } else {
                        ForEach(packs) { pack in
                            SearchPackRow(pack: pack)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        }
                    }
                case .rides:
                    if rides.isEmpty {
                        EmptyResultsView()
                    } else {
                        ForEach(rides) { ride in
                            SearchRideRow(ride: ride)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }
}

struct AllSearchResultsView: View {
    let results: SearchResults
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            if !results.users.isEmpty {
                SearchSectionHeader(title: "Users", count: results.users.count)
                ForEach(results.users.prefix(3)) { user in
                    GeneralSearchUserRow(user: user)
                        .padding(.horizontal)
                }
            }
            
            if !results.posts.isEmpty {
                SearchSectionHeader(title: "Posts", count: results.posts.count)
                ForEach(results.posts.prefix(3)) { post in
                    GeneralSearchPostRow(post: post)
                        .padding(.horizontal)
                }
            }
            
            if !results.packs.isEmpty {
                SearchSectionHeader(title: "Packs", count: results.packs.count)
                ForEach(results.packs.prefix(3)) { pack in
                    GeneralSearchPackRow(pack: pack)
                        .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
    }
}

struct SearchSectionHeader: View {
    let title: String
    let count: Int
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("(\(count))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct EmptyResultsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No results found")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Try adjusting your search terms")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Search Result Row Components

struct SearchUserRow: View {
    let user: SearchUser
    @State private var showingUserProfile = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image placeholder
            Circle()
                .fill(Color.blue)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(user.username.prefix(1).uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("@\(user.username)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                
                if let firstName = user.firstName, let lastName = user.lastName {
                    Text("\(firstName) \(lastName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let make = user.motorcycleMake, let model = user.motorcycleModel {
                    Text("\(make) \(model)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                if let safetyScore = user.safetyScore {
                    Text("Safety: \(safetyScore)")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                if let totalRides = user.totalRides {
                    Text("\(totalRides) rides")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
        .onTapGesture {
            showingUserProfile = true
        }
        .sheet(isPresented: $showingUserProfile) {
            SearchUserProfileView(user: user)
        }
    }
}

struct SearchPostRow: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(post.username.prefix(1).uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(post.username)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(timeAgo(from: post.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "doc.text")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
            
            Text(post.content)
                .font(.body)
                .lineLimit(3)
            
            HStack {
                Text("\(post.likesCount) likes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(post.commentsCount) comments")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct SearchStoryRow: View {
    let story: SearchStory
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LinearGradient(
                    colors: [.red, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(story.username.prefix(1).uppercased())
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                        )
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("@\(story.username)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let content = story.content, !content.isEmpty {
                    Text(content)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                } else {
                    Text("Story")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("Posted \(timeAgo(from: story.createdAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "play.circle.fill")
                .foregroundColor(.red)
                .font(.title2)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func timeAgo(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let date = formatter.date(from: dateString) {
            let relativeFormatter = RelativeDateTimeFormatter()
            return relativeFormatter.localizedString(for: date, relativeTo: Date())
        }
        return "Recently"
    }
}

struct SearchPackRow: View {
    let pack: SearchPack
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.white)
                        .font(.headline)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(pack.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Led by @\(pack.leaderUsername)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let description = pack.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(pack.memberCount) members")
                    .font(.caption)
                    .foregroundColor(.green)
                
                if let status = pack.status {
                    Text(status.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct SearchRideRow: View {
    let ride: SearchRide
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "motorcycle")
                        .foregroundColor(.white)
                        .font(.headline)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(ride.title ?? "Ride")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("by @\(ride.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let startLocation = ride.startLocationName {
                    Text("From: \(startLocation)")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                
                if let endLocation = ride.endLocationName {
                    Text("To: \(endLocation)")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                if let distance = ride.distance {
                    Text(String(format: "%.1f mi", distance * 0.000621371))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Text(ride.status.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - General Search Row Components

struct GeneralSearchUserRow: View {
    let user: GeneralSearchUser
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(user.username.prefix(1).uppercased())
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                
                if let firstName = user.firstName, let lastName = user.lastName {
                    Text("\(firstName) \(lastName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let safetyScore = user.safetyScore {
                Text("Safety: \(safetyScore)")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

struct GeneralSearchPostRow: View {
    let post: GeneralSearchPost
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "doc.text")
                        .foregroundColor(.white)
                        .font(.subheadline)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(post.username)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(post.content)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct GeneralSearchPackRow: View {
    let pack: GeneralSearchPack
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.green)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.white)
                        .font(.subheadline)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(pack.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Led by @\(pack.leaderUsername)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Search User Profile View
struct SearchUserProfileView: View {
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
                            .fill(Color.blue)
                            .overlay(
                                Text(user.username.prefix(1).uppercased())
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("@\(user.username)")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if user.isVerified {
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
                        Text("\(user.totalRides ?? 0)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("Total Rides")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)
                
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

// MARK: - Search Suggestions View
struct SearchSuggestionsView: View {
    let suggestions: [SearchSuggestion]
    let onSuggestionTap: (SearchSuggestion) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(suggestions) { suggestion in
                    Button(action: {
                        onSuggestionTap(suggestion)
                    }) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(suggestion.username.prefix(1).uppercased())
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.displayText)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                if let subtitle = suggestion.subtitle {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    SearchView()
        .environmentObject(SocialManager.shared)
} 