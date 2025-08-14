import SwiftUI

struct AdminPanelView: View {
    @EnvironmentObject var networkManager: NetworkManager
    @EnvironmentObject var socialManager: SocialManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var stats: AdminStats?
    @State private var users: [AdminUser] = []
    @State private var posts: [AdminPost] = []
    @State private var rides: [AdminRide] = []
    @State private var search: String = ""
    @State private var isLoading = false
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
            HStack { TextField("Search users", text: $search).textFieldStyle(RoundedBorderTextFieldStyle()); Button("Search") { loadUsers() } }
                .padding([.horizontal,.top])
            List {
                ForEach(users) { u in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Text("@\(u.username)").font(.headline); Spacer(); RoleBadge(role: u.role); TierBadge(tier: u.subscriptionTier) }
                        Text(u.email).font(.caption).foregroundColor(.secondary)
                        HStack {
                            Menu("Role: \(u.role)") { ForEach(["user","admin","super_admin"], id: \.self) { r in Button(r) { updateRole(u.id, r) } } }
                            Menu("Tier: \(u.subscriptionTier)") { ForEach(["standard","pro"], id: \.self) { t in Button(t) { updateTier(u.id, t) } } }
                        }
                    }
                }
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
    private func loadUsers() { networkManager.fetchAdminUsers(search: search) { if case let .success(list) = $0 { self.users = list } } }
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

struct AdminUser: Identifiable, Codable {
    let id: Int
    let username: String
    let email: String
    let role: String
    let subscriptionTier: String
    let isPremium: Bool?
}

struct RoleBadge: View { let role: String; var body: some View { Text(role).font(.caption2).padding(6).background(role == "super_admin" ? Color.red.opacity(0.2) : role == "admin" ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2)).cornerRadius(6) } }
struct TierBadge: View { let tier: String; var body: some View { Text(tier.capitalized).font(.caption2).padding(6).background(tier == "pro" ? Color.green.opacity(0.2) : Color.orange.opacity(0.2)).cornerRadius(6) } } 