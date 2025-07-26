import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var selectedTab = 0
    @State private var showingCreateChallenge = false
    @State private var timeframe: LeaderboardTimeframe = .weekly
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            VStack {
                // Tab picker
                Picker("Leaderboard Type", selection: $selectedTab) {
                    Text("Rankings").tag(0)
                    Text("Challenges").tag(1)
                    Text("Groups").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Content based on selected tab
                switch selectedTab {
                case 0:
                    RankingsView(timeframe: $timeframe)
                case 1:
                    ChallengesView(showingCreateChallenge: $showingCreateChallenge)
                case 2:
                    RideGroupsView()
                default:
                    RankingsView(timeframe: $timeframe)
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if selectedTab == 1 {
                            showingCreateChallenge = true
                        }
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .background(adaptiveBackground)
        }
    }
    
    private var adaptiveBackground: Color {
        colorScheme == .dark ? Color(.systemBackground) : Color(.systemGroupedBackground)
    }
}

struct RankingsView: View {
    @Binding var timeframe: LeaderboardTimeframe
    @EnvironmentObject var socialManager: SocialManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            // Timeframe picker
            Picker("Timeframe", selection: $timeframe) {
                Text("Weekly").tag(LeaderboardTimeframe.weekly)
                Text("Monthly").tag(LeaderboardTimeframe.monthly)
                Text("All Time").tag(LeaderboardTimeframe.allTime)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 0) {
                    // Top 3 podium
                    if socialManager.leaderboard.count >= 3 {
                        PodiumView(
                            first: socialManager.leaderboard[0].user,
                            second: socialManager.leaderboard[1].user,
                            third: socialManager.leaderboard[2].user
                        )
                        .padding(.vertical)
                    }
                    
                    // Current user's rank card
                    if let currentUser = socialManager.currentUser {
                        CurrentUserRankCard(user: currentUser)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                    
                    // Full leaderboard
                    LazyVStack(spacing: 0) {
                        ForEach(Array(socialManager.leaderboard.enumerated()), id: \.element.id) { index, entry in
                            LeaderboardRow(
                                user: entry.user,
                                rank: index + 1,
                                isCurrentUser: entry.user.id == socialManager.currentUser?.id
                            )
                        }
                    }
                    .background(adaptiveCardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .refreshable {
                await refreshLeaderboard()
            }
        }
        .background(adaptiveBackground)
    }
    
    private var adaptiveBackground: Color {
        colorScheme == .dark ? Color(.systemBackground) : Color(.systemGroupedBackground)
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    private func refreshLeaderboard() async {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        socialManager.updateLeaderboard()
    }
}

struct PodiumView: View {
    let first: User
    let second: User
    let third: User
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 20) {
            // Second place
            VStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(adaptiveGray)
                
                Text(second.username)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(second.stats.totalMiles) mi")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                VStack {
                    Text("2")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(width: 60, height: 80)
                .background(Color.gray)
                .cornerRadius(8)
            }
            
            // First place
            VStack {
                Image(systemName: first.isVerified ? "checkmark.seal.fill" : "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(first.isVerified ? .blue : adaptiveGray)
                
                Text(first.username)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("\(first.stats.totalMiles) mi")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack {
                    Image(systemName: "crown.fill")
                        .font(.title3)
                        .foregroundColor(.yellow)
                    
                    Text("1")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(width: 70, height: 100)
                .background(Color.yellow)
                .cornerRadius(8)
            }
            
            // Third place
            VStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(adaptiveGray)
                
                Text(third.username)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(third.stats.totalMiles) mi")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                VStack {
                    Text("3")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(width: 60, height: 60)
                .background(Color.orange)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(adaptiveCardBackground)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var adaptiveGray: Color {
        colorScheme == .dark ? Color.gray.opacity(0.8) : Color.gray
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
}

struct CurrentUserRankCard: View {
    let user: User
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Your Rank")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("#\(user.rank)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            VStack(alignment: .center) {
                Text("Miles This Week")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(user.stats.totalMiles)")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("Safety Score")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(user.stats.safetyScore)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}

struct LeaderboardRow: View {
    let user: User
    let rank: Int
    let isCurrentUser: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            // Rank
            Text("#\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(rankColor)
                .frame(width: 40)
            
            // Profile
            Image(systemName: user.isVerified ? "checkmark.seal.fill" : "person.circle.fill")
                .font(.title2)
                .foregroundColor(user.isVerified ? .blue : adaptiveGray)
            
            VStack(alignment: .leading) {
                Text(user.username)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary) // Ensure primary text has good contrast
                
                Text(user.bike)
                    .font(.caption)
                    .foregroundColor(adaptiveSecondary) // Use adaptive secondary color
            }
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing) {
                Text("\(user.stats.totalMiles) mi")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary) // Ensure primary text has good contrast
                
                Text("Safety: \(user.stats.safetyScore)")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(rowBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(adaptiveDivider),
            alignment: .bottom
        )
    }
    
    // Adaptive colors that work in both light and dark mode
    private var adaptiveGray: Color {
        colorScheme == .dark ? Color.gray.opacity(0.8) : Color.gray
    }
    
    private var adaptiveSecondary: Color {
        colorScheme == .dark ? Color.gray.opacity(0.7) : Color.secondary
    }
    
    private var adaptiveDivider: Color {
        colorScheme == .dark ? Color.gray.opacity(0.4) : Color.gray.opacity(0.3)
    }
    
    private var rowBackground: Color {
        if isCurrentUser {
            return colorScheme == .dark ? Color.red.opacity(0.2) : Color.red.opacity(0.1)
        }
        return Color.clear
    }
    
    private var rankColor: Color {
        switch rank {
        case 1:
            return .yellow
        case 2:
            return .gray
        case 3:
            return .orange
        default:
            return .primary
        }
    }
}

struct ChallengesView: View {
    @Binding var showingCreateChallenge: Bool
    @EnvironmentObject var socialManager: SocialManager
    @State private var selectedChallenge: Challenge?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Active challenges
                VStack(alignment: .leading, spacing: 12) {
                    Text("Active Challenges")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(socialManager.challenges.filter { !$0.isCompleted }) { challenge in
                            ChallengeCard(challenge: challenge) {
                                selectedChallenge = challenge
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Completed challenges
                VStack(alignment: .leading, spacing: 12) {
                    Text("Completed Challenges")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(socialManager.challenges.filter { $0.isCompleted }) { challenge in
                            ChallengeCard(challenge: challenge) {
                                selectedChallenge = challenge
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingCreateChallenge) {
            CreateChallengeView()
        }
        .sheet(item: $selectedChallenge) { challenge in
            ChallengeDetailView(challenge: challenge)
        }
    }
}

struct ChallengeCard: View {
    let challenge: Challenge
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(challenge.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(challenge.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Image(systemName: challenge.isCompleted ? "checkmark.circle.fill" : "clock")
                            .font(.title2)
                            .foregroundColor(challenge.isCompleted ? .green : .orange)
                        
                        Text("\(challenge.participants.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress bar
                if !challenge.isCompleted {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Progress")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(Int(challenge.progress * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        ProgressView(value: challenge.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .red))
                    }
                }
                
                // Reward
                HStack {
                    Image(systemName: "trophy.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    
                    Text("Reward: \(challenge.reward ?? "None")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(adaptiveCardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(challenge.isCompleted ? Color.green : adaptiveStroke, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    private var adaptiveStroke: Color {
        colorScheme == .dark ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3)
    }
}

struct CreateChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var socialManager: SocialManager
    @State private var title = ""
    @State private var description = ""
    @State private var targetMiles = 100
    @State private var duration = 7
    @State private var reward = "Badge"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Challenge Details")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("Requirements")) {
                    HStack {
                        Text("Target Miles")
                        Spacer()
                        TextField("Miles", value: $targetMiles, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Duration (days)")
                        Spacer()
                        TextField("Days", value: $duration, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                    }
                }
                
                Section(header: Text("Reward")) {
                    TextField("Reward", text: $reward)
                }
            }
            .navigationTitle("Create Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createChallenge()
                    }
                    .disabled(title.isEmpty || description.isEmpty)
                }
            }
        }
    }
    
    private func createChallenge() {
        let endDate = Calendar.current.date(byAdding: .day, value: duration, to: Date()) ?? Date()
        socialManager.createChallenge(
            title: title,
            description: description,
            goal: targetMiles,
            type: .distance,
            endDate: endDate
        )
        dismiss()
    }
}

struct ChallengeDetailView: View {
    let challenge: Challenge
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var socialManager: SocialManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(challenge.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(challenge.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Progress
                    if !challenge.isCompleted {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Progress")
                                .font(.headline)
                            
                            ProgressView(value: challenge.progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .red))
                            
                            Text("\(Int(challenge.progress * 100))% Complete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Participants
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Participants (\(challenge.participants.count))")
                            .font(.headline)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(challenge.participants, id: \.self) { participant in
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                    
                                    Text(participant)
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    Text("Active")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Join/Leave button
                    Button(action: {
                        toggleParticipation()
                    }) {
                        Text(isParticipating ? "Leave Challenge" : "Join Challenge")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(isParticipating ? Color.red : Color.green)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Challenge")
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
    
    private var isParticipating: Bool {
        guard let currentUser = socialManager.currentUser else { return false }
        return challenge.participants.contains(currentUser.username)
    }
    
    private func toggleParticipation() {
        if isParticipating {
            // Leave challenge logic
            print("Leaving challenge: \(challenge.title)")
        } else {
            socialManager.joinChallenge(challenge)
        }
    }
}

struct RideGroupsView: View {
    @EnvironmentObject var socialManager: SocialManager
    @State private var selectedGroup: RideGroup?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(socialManager.rideGroups) { group in
                    RideGroupCard(group: group) {
                        selectedGroup = group
                    }
                }
            }
            .padding()
        }
        .sheet(item: $selectedGroup) { group in
            RideGroupDetailView(group: group)
        }
    }
}

struct RideGroupCard: View {
    let group: RideGroup
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(group.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(group.location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Image(systemName: "person.3.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                        
                        Text("\(group.memberCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(group.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text("Next Ride:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(group.nextRideDate)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(group.isActive ? "Active" : "Inactive")
                        .font(.caption)
                        .foregroundColor(group.isActive ? .green : .gray)
                }
            }
            .padding()
            .background(adaptiveCardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(adaptiveStroke, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    private var adaptiveStroke: Color {
        colorScheme == .dark ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3)
    }
}

struct RideGroupDetailView: View {
    let group: RideGroup
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var socialManager: SocialManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(group.location)
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text(group.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Next ride info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Next Ride")
                            .font(.headline)
                        
                        Text(group.nextRideDate)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Join button
                    Button(action: {
                        joinGroup()
                    }) {
                        Text("Join Group")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Ride Group")
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
    
    private func joinGroup() {
        socialManager.joinRideGroup(group)
    }
}

enum LeaderboardTimeframe {
    case weekly, monthly, allTime
}

#Preview {
    LeaderboardView()
        .environmentObject(SocialManager.shared)
        .environmentObject(LocationManager.shared)
} 