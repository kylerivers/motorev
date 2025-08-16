import SwiftUI

struct AdminPanelView: View {
    @EnvironmentObject var networkManager: NetworkManager
    @EnvironmentObject var socialManager: SocialManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var stats: AdminStats?
    @State private var users: [AdminUser] = []
    @State private var allUsers: [AdminUser] = [] // Store all users for filtering
    @State private var posts: [AdminPost] = []
    @State private var rides: [AdminRide] = []
    @State private var search: String = ""
    @State private var isLoading = false
    @State private var isLoadingMoreUsers = false
    @State private var hasMoreUsers = true
    @State private var currentPage = 1
    @State private var hazards: [AdminHazard] = []
    @State private var emergencies: [AdminEmergency] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Section", selection: $selectedTab) {
                    Text("Overview").tag(0)
                    Text("Users").tag(1)
                    Text("Posts").tag(2)
                    Text("Rides").tag(3)
                    Text("Hazards").tag(4)
                    Text("Emergencies").tag(5)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                Group {
                    switch selectedTab {
                    case 0: overview
                    case 1: usersList
                    case 2: postsList
                    case 3: ridesList
                    case 4: hazardsList
                    default: emergenciesList
                    }
                }
                .overlay { if isLoading { ProgressView() } }
                .onAppear { loadAll() }
            }
            .navigationTitle("Admin Panel")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
    
    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let s = stats {
                    AdminStatGrid(stats: s)
                }
                if !rides.isEmpty || !posts.isEmpty {
                    AdminChartsSection(posts: posts, rides: rides)
                }
                Divider()
                Text("Recent Activity").font(.headline)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(posts.prefix(5)) { p in
                        Text("Post #\(p.id) • Likes: \(p.likes_count ?? 0) • Comments: \(p.comments_count ?? 0)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
    }
    
    private var usersList: some View {
        VStack {
            // Search bar with instant filtering
            HStack { 
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search users by username, email, or name...", text: $search)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: search) { _, newValue in
                        filterUsers()
                    }
                
                if !search.isEmpty {
                    Button("Clear") {
                        search = ""
                        filterUsers()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding([.horizontal,.top])
            
            // Results info
            HStack {
                Text("Showing \(filteredUsers.count) of \(allUsers.count) users")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if isLoadingMoreUsers {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)
            
            // Users list with infinite scroll
            List {
                ForEach(filteredUsers) { user in
                    NavigationLink(destination: UserDetailView(user: user, onUpdate: { 
                        loadAllUsers() // Refresh the full list
                    })) {
                        UserRowView(user: user) {
                            loadAllUsers()
                        }
                    }
                    .onAppear {
                        // Load more when reaching the last few items
                        if user.id == filteredUsers.last?.id && hasMoreUsers && search.isEmpty {
                            loadMoreUsers()
                        }
                    }
                }
                
                // Loading indicator at bottom
                if isLoadingMoreUsers {
                    HStack {
                        Spacer()
                        ProgressView("Loading more users...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                }
            }
            .refreshable {
                await refreshUsers()
            }
        }
        .onAppear {
            if allUsers.isEmpty {
                loadAllUsers()
            }
        }
    }
    
    // Computed property for filtered users
    private var filteredUsers: [AdminUser] {
        if search.isEmpty {
            return users // Show paginated results when not searching
        } else {
            return allUsers.filter { user in
                user.username.localizedCaseInsensitiveContains(search) ||
                user.email.localizedCaseInsensitiveContains(search) ||
                (user.firstName?.localizedCaseInsensitiveContains(search) ?? false) ||
                (user.lastName?.localizedCaseInsensitiveContains(search) ?? false)
            }
        }
    }
    
    private var postsList: some View {
        List {
            ForEach(posts) { p in
                VStack(alignment: .leading, spacing: 6) {
                    Text(p.content ?? "(no content)")
                    HStack { Text("Post #\(p.id)").font(.caption).foregroundColor(.secondary); Spacer(); Text("❤️ \(p.likes_count ?? 0)  💬 \(p.comments_count ?? 0)").font(.caption) }
                }
            }
        }
        .onAppear { if posts.isEmpty { loadPosts() } }
    }
    
    private var ridesList: some View {
        List {
            ForEach(rides) { r in
                VStack(alignment: .leading, spacing: 6) {
                    Text(r.title ?? "Ride #\(r.id)")
                    HStack {
                        Text("Dist: \(String(format: "%.1f", r.total_distance ?? 0)) mi").font(.caption)
                        Text("Avg: \(String(format: "%.0f", r.avg_speed ?? 0)) mph").font(.caption)
                        Text("Max: \(String(format: "%.0f", r.max_speed ?? 0)) mph").font(.caption)
                        Spacer()
                        Text(r.status ?? "").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear { if rides.isEmpty { loadRides() } }
    }
    
    private var hazardsList: some View {
        List {
            ForEach(hazards) { h in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(h.hazard_type ?? "hazard") • \(h.severity ?? "")")
                    HStack {
                        Text(h.location_name ?? "").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Menu("Status: \(h.status ?? "")") {
                            ForEach(["active","resolved","duplicate","false_report"], id: \.self) { s in
                                Button(s) { updateHazard(h.id, s) }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { if hazards.isEmpty { loadHazards() } }
    }
    
    private var emergenciesList: some View {
        List {
            ForEach(emergencies) { e in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(e.event_type ?? "emergency") • \(e.severity ?? "")")
                    HStack {
                        Text(e.location_name ?? "").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Button(e.is_resolved == 1 ? "Mark Unresolved" : "Mark Resolved") {
                            toggleEmergency(e.id, resolved: e.is_resolved != 1)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .onAppear { if emergencies.isEmpty { loadEmergencies() } }
    }
    
    private func loadAll() {
        isLoading = true
        networkManager.fetchAdminStats { result in if case let .success(s) = result { self.stats = s }; self.isLoading = false }
        loadUsers(); loadPosts(); loadRides(); loadHazards(); loadEmergencies()
    }
    private func loadUsers() { 
        networkManager.fetchAdminUsers(search: search) { if case let .success(list) = $0 { 
            self.users = list 
            if self.allUsers.isEmpty {
                self.allUsers = list
            }
        } } 
    }
    
    private func loadAllUsers() {
        isLoading = true
        currentPage = 1
        hasMoreUsers = true
        
        print("🔵 [AdminPanel] Starting loadAllUsers - page: \(currentPage)")
        
        networkManager.fetchAdminUsers(search: "", page: currentPage, limit: 20) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let list):
                    print("✅ [AdminPanel] Successfully loaded \(list.count) users")
                    self.allUsers = list
                    self.users = Array(list.prefix(20))
                    self.hasMoreUsers = list.count >= 20
                    print("🔵 [AdminPanel] hasMoreUsers: \(self.hasMoreUsers)")
                case .failure(let error):
                    print("❌ [AdminPanel] Failed to load users: \(error)")
                    self.hasMoreUsers = false
                }
                self.isLoading = false
            }
        }
    }
    
    private func loadMoreUsers() {
        guard !isLoadingMoreUsers && hasMoreUsers else { 
            print("🔶 [AdminPanel] Skipping loadMoreUsers - isLoadingMoreUsers: \(isLoadingMoreUsers), hasMoreUsers: \(hasMoreUsers)")
            return 
        }
        
        isLoadingMoreUsers = true
        currentPage += 1
        
        print("🔵 [AdminPanel] Starting loadMoreUsers - page: \(currentPage)")
        
        networkManager.fetchAdminUsers(search: "", page: currentPage, limit: 20) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let list):
                    print("✅ [AdminPanel] Successfully loaded \(list.count) more users")
                    self.users.append(contentsOf: list)
                    self.allUsers.append(contentsOf: list)
                    self.hasMoreUsers = list.count >= 20
                    print("🔵 [AdminPanel] hasMoreUsers: \(self.hasMoreUsers), total users: \(self.allUsers.count)")
                case .failure(let error):
                    print("❌ [AdminPanel] Failed to load more users: \(error)")
                    self.hasMoreUsers = false
                }
                self.isLoadingMoreUsers = false
            }
        }
    }
    
    private func filterUsers() {
        // Filtering is handled by the computed property
    }
    
    private func refreshUsers() async {
        currentPage = 1
        hasMoreUsers = true
        users.removeAll()
        allUsers.removeAll()
        loadAllUsers()
    }
    private func loadPosts() { networkManager.fetchAdminPosts() { if case let .success(list) = $0 { self.posts = list } } }
    private func loadRides() { networkManager.fetchAdminRides() { if case let .success(list) = $0 { self.rides = list } } }
    private func loadHazards() { networkManager.fetchAdminHazards() { if case let .success(list) = $0 { self.hazards = list } } }
    private func loadEmergencies() { networkManager.fetchAdminEmergencies() { if case let .success(list) = $0 { self.emergencies = list } } }
    private func updateRole(_ userId: Int, _ role: String) { networkManager.updateUserRole(userId: userId, role: role) { _ in loadUsers() } }
    private func updateTier(_ userId: Int, _ tier: String) { networkManager.updateUserSubscription(userId: userId, tier: tier) { _ in loadUsers() } }
    private func updateHazard(_ id: Int, _ status: String) { networkManager.updateHazardStatus(hazardId: id, status: status) { _ in loadHazards() } }
    private func toggleEmergency(_ id: Int, resolved: Bool) { networkManager.resolveEmergency(emergencyId: id, resolved: resolved) { _ in loadEmergencies() } }
}

struct AdminStatGrid: View {
    let stats: AdminStats
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            AdminStatCard(title: "Users", value: stats.users)
            AdminStatCard(title: "Posts", value: stats.posts)
            AdminStatCard(title: "Rides", value: stats.rides)
            AdminStatCard(title: "Stories", value: stats.stories)
            AdminStatCard(title: "Likes", value: stats.post_likes)
            AdminStatCard(title: "Comments", value: stats.post_comments)
            AdminStatCard(title: "Followers", value: stats.followers)
            AdminStatCard(title: "Hazards", value: stats.hazard_reports)
        }
    }
}

struct AdminStatCard: View {
    let title: String
    let value: Int?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text("\(value ?? 0)").font(.title2).bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Charts
struct AdminChartsSection: View {
    let posts: [AdminPost]
    let rides: [AdminRide]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trends").font(.headline)
            VStack(spacing: 12) {
                if !posts.isEmpty {
                    MiniBarChart(title: "Posts per day (last 10)", data: bucketCounts(dates: posts.compactMap { isoToDate($0.created_at) }))
                }
                if !rides.isEmpty {
                    MiniBarChart(title: "Rides per day (last 10)", data: bucketCounts(dates: rides.compactMap { isoToDate($0.start_time) }))
                }
            }
            .padding()
            .background(Color.gray.opacity(0.08))
            .cornerRadius(12)
        }
    }

    private func isoToDate(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        // Try ISO8601 and fallback
        let f = ISO8601DateFormatter()
        if let d = f.date(from: iso) { return d }
        let g = DateFormatter(); g.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return g.date(from: iso)
    }

    private func bucketCounts(dates: [Date]) -> [(String, Int)] {
        let cal = Calendar.current
        let buckets = Dictionary(grouping: dates) { d in
            let comps = cal.dateComponents([.year, .month, .day], from: d)
            return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
        }
        let sorted = buckets.keys.sorted().suffix(10)
        return sorted.map { key in (key, buckets[key]?.count ?? 0) }
    }
}

struct MiniBarChart: View {
    let title: String
    let data: [(String, Int)] // (label, value)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline).foregroundColor(.secondary)
            HStack(alignment: .bottom, spacing: 6) {
                let maxVal = max(1, data.map { $0.1 }.max() ?? 1)
                ForEach(Array(data.enumerated()), id: \.offset) { _, point in
                    VStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue.opacity(0.8))
                            .frame(width: 14, height: CGFloat(point.1) / CGFloat(maxVal) * 80)
                        Text(String(point.0.suffix(5)))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(-45))
                            .frame(height: 12)
                    }
                }
            }
        }
    }
}

// Use BackendUser directly for admin panel
typealias AdminUser = BackendUser

struct RoleBadge: View { let role: String; var body: some View { Text(role).font(.caption2).padding(6).background(role == "super_admin" ? Color.red.opacity(0.2) : role == "admin" ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2)).cornerRadius(6) } }
struct TierBadge: View { let tier: String; var body: some View { Text(tier.capitalized).font(.caption2).padding(6).background(tier == "pro" ? Color.green.opacity(0.2) : Color.orange.opacity(0.2)).cornerRadius(6) } }

// MARK: - User Detail View

struct UserDetailView: View {
    let user: AdminUser
    let onUpdate: () -> Void
    @EnvironmentObject var networkManager: NetworkManager
    @Environment(\.dismiss) private var dismiss
    @State private var isUpdating = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // User Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("@\(user.username)")
                            .font(.title)
                            .fontWeight(.bold)
                        Spacer()
                        RoleBadge(role: user.role ?? "user")
                        TierBadge(tier: user.subscriptionTier ?? "standard")
                    }
                    
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let firstName = user.firstName, let lastName = user.lastName {
                        Text("\(firstName) \(lastName)")
                            .font(.subheadline)
                    }
                }
                
                // User Stats
                VStack(alignment: .leading, spacing: 12) {
                    Text("Statistics")
                        .font(.headline)
                    
                    HStack {
                        StatBox(title: "Total Rides", value: "\(user.totalRides ?? 0)")
                        StatBox(title: "Total Miles", value: String(format: "%.1f", user.totalMiles ?? 0))
                        StatBox(title: "Safety Score", value: "\(user.safetyScore ?? 100)")
                    }
                    
                    HStack {
                        StatBox(title: "Posts", value: "\(user.postsCount ?? 0)")
                        StatBox(title: "Followers", value: "\(user.followersCount ?? 0)")
                        StatBox(title: "Following", value: "\(user.followingCount ?? 0)")
                    }
                }
                
                // Account Management
                VStack(alignment: .leading, spacing: 12) {
                    Text("Account Management")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Subscription Tier:")
                                .fontWeight(.medium)
                            Spacer()
                            Menu((user.subscriptionTier ?? "standard").capitalized) {
                                Button("Standard") { updateTier("standard") }
                                Button("Pro") { updateTier("pro") }
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        HStack {
                            Text("Role:")
                                .fontWeight(.medium)
                            Spacer()
                            Menu((user.role ?? "user").capitalized) {
                                Button("User") { updateRole("user") }
                                Button("Admin") { updateRole("admin") }
                                Button("Super Admin") { updateRole("super_admin") }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                // Motorcycle Info
                if let make = user.motorcycleMake, let model = user.motorcycleModel {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Motorcycle")
                            .font(.headline)
                        
                        Text("\(make) \(model)")
                            .font(.subheadline)
                        
                        if let year = user.motorcycleYear {
                            Text("Year: \(year)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Account Dates
                VStack(alignment: .leading, spacing: 8) {
                    Text("Account Information")
                        .font(.headline)
                    
                    Text("Created: \(user.createdAt)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Updated: \(user.updatedAt)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Status: \(user.status ?? "Active")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("User Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .overlay {
            if isUpdating {
                ProgressView("Updating...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 4)
            }
        }
    }
    
    private func updateTier(_ tier: String) {
        isUpdating = true
        // TODO: Call actual API to update tier
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isUpdating = false
            self.onUpdate()
        }
    }
    
    private func updateRole(_ role: String) {
        isUpdating = true
        // TODO: Call actual API to update role
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isUpdating = false
            self.onUpdate()
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - User Row View

struct UserRowView: View {
    let user: AdminUser
    let onUpdate: () -> Void
    @EnvironmentObject var networkManager: NetworkManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { 
                Text("@\(user.username)")
                    .font(.headline)
                Spacer()
                RoleBadge(role: user.role ?? "user")
                TierBadge(tier: user.subscriptionTier ?? "standard")
            }
            
            Text(user.email)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Rides: \(user.totalRides ?? 0)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Safety: \(user.safetyScore ?? 100)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Quick action buttons
            HStack {
                if (user.subscriptionTier ?? "standard") == "standard" {
                    Button("Grant Pro") {
                        updateTier(String(user.id), "pro")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(4)
                }
                
                if (user.role ?? "user") == "user" {
                    Button("Make Admin") {
                        updateRole(String(user.id), "admin")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
    
    private func updateTier(_ userId: String, _ tier: String) {
        // TODO: Call actual API to update tier
        if let userIdInt = Int(userId) {
            networkManager.updateUserSubscription(userId: userIdInt, tier: tier) { _ in
                onUpdate()
            }
        }
    }
    
    private func updateRole(_ userId: String, _ role: String) {
        // TODO: Call actual API to update role  
        if let userIdInt = Int(userId) {
            networkManager.updateUserRole(userId: userIdInt, role: role) { _ in
                onUpdate()
            }
        }
    }
} 