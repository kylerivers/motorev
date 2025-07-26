import SwiftUI
import Combine

struct ProfileView: View {
    @EnvironmentObject var networkManager: NetworkManager
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var safetyManager: SafetyManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var watchManager: WatchManager
    @State private var showingSettings = false
    @State private var showingEditProfile = false
    @State private var showingStatistics = false
    @State private var showingEmergencyContacts = false
    @State private var showingLogoutAlert = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile header
                    if let user = socialManager.currentUser {
                        ProfileHeaderView(user: user)
                    }
                    
                    // Stats overview
                    StatsOverviewView()
                    
                    // Safety section
                    SafetyConfigurationView()
                    
                    // Watch integration
                    WatchIntegrationView()
                    
                    // Settings sections
                    SettingsListView(
                        showingSettings: $showingSettings,
                        showingEditProfile: $showingEditProfile,
                        showingStatistics: $showingStatistics,
                        showingEmergencyContacts: $showingEmergencyContacts,
                        showingLogoutAlert: $showingLogoutAlert
                    )
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingEditProfile = true
                    }) {
                        Image(systemName: "pencil")
                    }
                }
            }
            .onAppear {
                // Clear notifications when profile is viewed
                socialManager.markNotificationsAsRead()
                // Refresh user profile data to ensure latest data is shown
                socialManager.refreshUserProfile()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showingStatistics) {
                StatisticsView()
            }
            .sheet(isPresented: $showingEmergencyContacts) {
                EmergencyContactsView()
            }
            .alert("Log Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    performLogout()
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
        }
    }
    
    private func performLogout() {
        // Always perform local logout to ensure UI updates
        networkManager.forceLogout()
        
        // Also try API logout but don't wait for it
        networkManager.logout()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("⚠️ Logout API call failed: \(error)")
                    }
                    print("✅ Logout API call completed")
                },
                receiveValue: { _ in
                    print("✅ Logout successful via API")
                }
            )
            .store(in: &cancellables)
    }
}

struct ProfileHeaderView: View {
    let user: User
    @Environment(\.colorScheme) var colorScheme
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @EnvironmentObject var socialManager: SocialManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile image and basic info
            VStack(spacing: 12) {
                // Tappable profile image
                Button(action: { showingImagePicker = true }) {
                    Group {
                        if let selectedImage = selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else if let profilePictureUrl = user.profilePictureUrl, !profilePictureUrl.isEmpty {
                            AsyncImage(url: URL(string: profilePictureUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    )
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: user.isVerified ? "checkmark.seal.fill" : "person.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(user.isVerified ? .blue : adaptiveGray)
                        }
                    }
                    .overlay(
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                            .opacity(0.3)
                    )
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 24, height: 24)
                            )
                            .offset(x: 28, y: 28)
                    )
                }
                
                VStack(spacing: 4) {
                    HStack {
                        Text("@\(user.username)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                    }
                    
                    if let firstName = user.firstName, let lastName = user.lastName {
                        Text("\(firstName) \(lastName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(user.bike)
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                    
                    if !user.bio.isEmpty {
                        Text(user.bio)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal)
                    }
                    
                    HStack {
                        Text("Rank #\(user.rank)")
                            .font(.caption)
                            .foregroundColor(.red)
                        
                        Circle()
                            .fill(adaptiveGray)
                            .frame(width: 4, height: 4)
                        
                        Text("Safety Score: \(user.stats.safetyScore)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            // Social stats
            HStack(spacing: 40) {
                VStack {
                    Text("\(user.stats.totalRides)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Rides")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(user.stats.totalMiles)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Miles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(user.followersCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Followers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(user.followingCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Following")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(adaptiveCardBackground)
        .cornerRadius(16)
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(selectedImage: $selectedImage)
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                uploadProfileImage(image)
            }
        }
    }
    
    private var adaptiveGray: Color {
        colorScheme == .dark ? Color.gray.opacity(0.8) : Color.gray
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
}

struct StatsOverviewView: View {
    @EnvironmentObject var socialManager: SocialManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This Week")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Miles",
                    value: "\(socialManager.currentUser?.stats.totalMiles ?? 0)",
                    icon: "road.lanes",
                    color: .blue
                )
                
                StatCard(
                    title: "Rides",
                    value: "\(socialManager.currentUser?.stats.totalRides ?? 0)",
                    icon: "motorcycle",
                    color: .red
                )
            }
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Avg Speed",
                    value: "\(socialManager.currentUser?.stats.averageSpeed ?? 0) mph",
                    icon: "speedometer",
                    color: .orange
                )
                
                StatCard(
                    title: "Safety Score",
                    value: "\(socialManager.currentUser?.stats.safetyScore ?? 0)",
                    icon: "shield",
                    color: .green
                )
            }
        }
        .padding()
        .background(adaptiveCardBackground)
        .cornerRadius(16)
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(adaptiveCardBackground)
        .cornerRadius(12)
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? color.opacity(0.2) : color.opacity(0.1)
    }
}

struct SafetyConfigurationView: View {
    @EnvironmentObject var safetyManager: SafetyManager
    @EnvironmentObject var crashDetectionManager: CrashDetectionManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Safety Configuration")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                // Safety status
                HStack {
                    Image(systemName: "shield.checkered")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading) {
                        Text("Safety Status")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(safetyStatusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(safetyStatusText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(safetyStatusColor)
                }
                .padding()
                .background(adaptiveItemBackground)
                .cornerRadius(12)
                
                // Crash detection toggle
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading) {
                        Text("Crash Detection")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Monitor for accidents")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: .init(
                        get: { crashDetectionManager.isMonitoring },
                        set: { newValue in
                            if newValue {
                                crashDetectionManager.startMonitoring()
                            } else {
                                crashDetectionManager.stopMonitoring()
                            }
                        }
                    ))
                    .scaleEffect(0.8)
                }
                .padding()
                .background(adaptiveItemBackground)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(adaptiveCardBackground)
        .cornerRadius(16)
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    private var adaptiveItemBackground: Color {
        colorScheme == .dark ? Color(.systemGray5) : Color.gray.opacity(0.1)
    }
    
    private var safetyStatusText: String {
        switch safetyManager.safetyStatus {
        case .safe:
            return "Safe"
        case .warning:
            return "Warning"
        case .emergency:
            return "Emergency"
        case .crashDetected:
            return "Crash Detected"
        }
    }
    
    private var safetyStatusColor: Color {
        switch safetyManager.safetyStatus {
        case .safe:
            return .green
        case .warning:
            return .yellow
        case .emergency, .crashDetected:
            return .red
        }
    }
}

struct WatchIntegrationView: View {
    @EnvironmentObject var watchManager: WatchManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Apple Watch")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                // Connection status
                HStack {
                    Image(systemName: "applewatch")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("Connection Status")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(watchManager.isWatchConnected ? "Connected" : "Disconnected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Circle()
                        .fill(watchManager.isWatchConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                }
                .padding()
                .background(adaptiveItemBackground)
                .cornerRadius(12)
                
                // Battery level
                if watchManager.isWatchConnected {
                    HStack {
                        Image(systemName: "battery.100")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading) {
                            Text("Battery Level")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("\(Int(watchManager.watchBatteryLevel * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        ProgressView(value: Double(watchManager.watchBatteryLevel))
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                            .frame(width: 50)
                    }
                    .padding()
                    .background(adaptiveItemBackground)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(adaptiveCardBackground)
        .cornerRadius(16)
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    private var adaptiveItemBackground: Color {
        colorScheme == .dark ? Color(.systemGray5) : Color.gray.opacity(0.1)
    }
}

struct SettingsListView: View {
    @Binding var showingSettings: Bool
    @Binding var showingEditProfile: Bool
    @Binding var showingStatistics: Bool
    @Binding var showingEmergencyContacts: Bool
    @Binding var showingLogoutAlert: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                SettingsRow(
                    title: "Edit Profile",
                    subtitle: "Update your profile information",
                    icon: "person.crop.circle",
                    action: { showingEditProfile = true }
                )
                
                SettingsRow(
                    title: "Statistics",
                    subtitle: "View detailed ride statistics",
                    icon: "chart.bar.fill",
                    action: { showingStatistics = true }
                )
                
                SettingsRow(
                    title: "Emergency Contacts",
                    subtitle: "Manage your emergency contacts",
                    icon: "person.3.fill",
                    action: { showingEmergencyContacts = true }
                )
                
                SettingsRow(
                    title: "App Settings",
                    subtitle: "Configure app preferences",
                    icon: "gearshape.fill",
                    action: { showingSettings = true }
                )
                
                SettingsRow(
                    title: "Log Out",
                    subtitle: "Sign out of your account",
                    icon: "arrow.right.square",
                    action: { showingLogoutAlert = true }
                )
            }
        }
        .padding()
        .background(adaptiveCardBackground)
        .cornerRadius(16)
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
}

struct SettingsRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.red)
                    .frame(width: 30)
                
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(adaptiveRowBackground)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var adaptiveRowBackground: Color {
        colorScheme == .dark ? Color(.systemGray5) : Color.gray.opacity(0.1)
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var networkManager: NetworkManager
    
    // Profile fields
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phoneNumber = ""
    @State private var motorcycleMake = ""
    @State private var motorcycleModel = ""
    @State private var motorcycleYear = ""
    @State private var ridingExperience = "beginner"
    @State private var bio = ""
    
    // Profile image
    @State private var profileImage: UIImage?
    @State private var showingImagePicker = false
    
    // Privacy settings
    @State private var publicProfile = true
    @State private var showLocation = false
    @State private var shareRideData = true
    
    // UI state
    @State private var isLoading = false
    @State private var showSuccessMessage = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // Combine cancellables
    @State private var cancellables = Set<AnyCancellable>()
    
    private let ridingExperiences = ["beginner", "intermediate", "advanced", "expert"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Picture")) {
                    HStack {
                        Spacer()
                        
                        Button(action: { showingImagePicker = true }) {
                            Group {
                                if let profileImage = profileImage {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } else if let profilePictureUrl = socialManager.currentUser?.profilePictureUrl, !profilePictureUrl.isEmpty {
                                    AsyncImage(url: URL(string: profilePictureUrl)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .overlay(
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                            )
                                    }
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 100))
                                        .foregroundColor(.gray)
                                }
                            }
                            .overlay(
                                Circle()
                                    .stroke(Color.blue, lineWidth: 3)
                                    .opacity(0.3)
                            )
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .background(
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 30, height: 30)
                                    )
                                    .offset(x: 35, y: 35)
                            )
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical)
                    
                    Text("Tap to change your profile picture")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                Section(header: Text("Personal Information")) {
                    TextField("First Name", text: $firstName)
                        .autocapitalization(.words)
                    
                    TextField("Last Name", text: $lastName)
                        .autocapitalization(.words)
                    
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }
                
                Section(header: Text("Motorcycle Information")) {
                    TextField("Make (e.g., Honda, Yamaha)", text: $motorcycleMake)
                        .autocapitalization(.words)
                    
                    TextField("Model (e.g., CBR600RR, R1)", text: $motorcycleModel)
                        .autocapitalization(.words)
                    
                    TextField("Year", text: $motorcycleYear)
                        .keyboardType(.numberPad)
                        .onChange(of: motorcycleYear) { oldValue, newValue in
                            // Limit to 4 digits
                            if newValue.count > 4 {
                                motorcycleYear = String(newValue.prefix(4))
                            }
                            // Only allow numbers
                            motorcycleYear = newValue.filter { $0.isNumber }
                        }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Riding Experience")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Riding Experience", selection: $ridingExperience) {
                            ForEach(ridingExperiences, id: \.self) { experience in
                                Text(experience.capitalized).tag(experience)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                
                Section(header: Text("About")) {
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Text("Share a bit about yourself and your riding style")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Social & Privacy Settings")) {
                    Toggle("Public Profile", isOn: $publicProfile)
                    Toggle("Show Location", isOn: $showLocation)
                    Toggle("Share Ride Data", isOn: $shareRideData)
                }
                
                if showSuccessMessage {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Profile updated successfully!")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        print("🔘 Save button pressed")
                        saveProfile()
                    }
                    .disabled(isLoading || !isFormValid)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerView(selectedImage: $profileImage)
            }
            .onAppear {
                loadCurrentProfile()
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") {
                    showErrorAlert = false
                }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func loadCurrentProfile() {
        if let user = socialManager.currentUser {
            // Load actual user data from the current user
            firstName = user.firstName ?? ""
            lastName = user.lastName ?? ""
            phoneNumber = user.phone ?? ""
            bio = user.bio
            
            // Load motorcycle information from individual fields (preferred) or fallback to bike field
            motorcycleMake = user.motorcycleMake ?? ""
            motorcycleModel = user.motorcycleModel ?? ""
            motorcycleYear = user.motorcycleYear != nil ? String(user.motorcycleYear!) : ""
            
            // Fallback: Parse the existing bike field if individual fields are empty
            if motorcycleMake.isEmpty && motorcycleModel.isEmpty && !user.bike.isEmpty {
                let bikeComponents = user.bike.components(separatedBy: " ")
                if bikeComponents.count >= 2 {
                    motorcycleMake = bikeComponents[0]
                    motorcycleModel = bikeComponents[1...].joined(separator: " ")
                } else {
                    motorcycleMake = user.bike
                }
            }
            
            // Set riding experience from user data
            ridingExperience = user.ridingExperience.rawValue
        }
        
        // Load privacy settings
        publicProfile = UserDefaults.standard.object(forKey: "publicProfileEnabled") as? Bool ?? true
        showLocation = UserDefaults.standard.object(forKey: "showLocationEnabled") as? Bool ?? false
        shareRideData = UserDefaults.standard.object(forKey: "shareRideDataEnabled") as? Bool ?? true
    }
    
    private func saveProfile() {
        print("🔄 saveProfile() called - starting profile save")
        isLoading = true
        showSuccessMessage = false
        
        // Convert profile image to base64 string if available
        var profilePictureData: String? = nil
        if let image = profileImage {
            if let imageData = image.jpegData(compressionQuality: 0.7) {
                profilePictureData = imageData.base64EncodedString()
            }
        }
        
        print("✅ Saving profile:")
        print("   Name: \(firstName) \(lastName)")
        print("   Phone: \(phoneNumber)")
        print("   Bike: \(motorcycleMake) \(motorcycleModel) (\(motorcycleYear))")
        print("   Experience: \(ridingExperience)")
        print("   Bio: \(bio)")
        
        // Update profile via NetworkManager with proper response handling
        networkManager.updateProfile(
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty ? nil : phoneNumber.trimmingCharacters(in: .whitespaces),
            motorcycleMake: motorcycleMake.trimmingCharacters(in: .whitespaces).isEmpty ? nil : motorcycleMake.trimmingCharacters(in: .whitespaces),
            motorcycleModel: motorcycleModel.trimmingCharacters(in: .whitespaces).isEmpty ? nil : motorcycleModel.trimmingCharacters(in: .whitespaces),
            motorcycleYear: motorcycleYear.trimmingCharacters(in: .whitespaces).isEmpty ? nil : motorcycleYear.trimmingCharacters(in: .whitespaces),
            ridingExperience: ridingExperience,
            bio: bio.trimmingCharacters(in: .whitespaces).isEmpty ? nil : bio.trimmingCharacters(in: .whitespaces),
            profilePicture: profilePictureData
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    print("❌ Failed to update profile: \(error)")
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            },
            receiveValue: { response in
                print("✅ Profile update successful - received response")
                
                // Update SocialManager's current user
                socialManager.updateCurrentUserFromBackend(response.user)
                
                // Save privacy settings to UserDefaults
                UserDefaults.standard.set(publicProfile, forKey: "publicProfileEnabled")
                UserDefaults.standard.set(showLocation, forKey: "showLocationEnabled")
                UserDefaults.standard.set(shareRideData, forKey: "shareRideDataEnabled")
                
                // Update SocialManager profile visibility
                socialManager.setProfileVisibility(isPublic: publicProfile)
                
                // Show success message
                showSuccessMessage = true
                print("✅ Profile updated successfully and UI refreshed")
                
                // Reload the form with the updated data from the response AFTER showing success
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    loadCurrentProfile()
                }
                
                // Hide success message and dismiss after 2.5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    dismiss()
                }
            }
        )
        .store(in: &cancellables)
    }
}

struct StatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Overall stats
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Overall Statistics")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            StatCard(title: "Total Miles", value: "\(socialManager.currentUser?.stats.totalMiles ?? 0)", icon: "road.lanes", color: .blue)
                            StatCard(title: "Total Rides", value: "\(socialManager.currentUser?.stats.totalRides ?? 0)", icon: "motorcycle", color: .red)
                            StatCard(title: "Avg Speed", value: "\(socialManager.currentUser?.stats.averageSpeed ?? 0) mph", icon: "speedometer", color: .orange)
                            StatCard(title: "Longest Ride", value: "\(socialManager.currentUser?.stats.longestRide ?? 0) mi", icon: "road.lanes.curved.right", color: .green)
                        }
                    }
                    .padding()
                    .background(adaptiveCardBackground)
                    .cornerRadius(16)
                    
                    // Recent rides
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent Rides")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(locationManager.rideHistory) { ride in
                                RideHistoryRow(ride: ride)
                            }
                        }
                    }
                    .padding()
                    .background(adaptiveCardBackground)
                    .cornerRadius(16)
                }
                .padding()
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .background(adaptiveBackground)
        }
    }
    
    private var adaptiveBackground: Color {
        colorScheme == .dark ? Color(.systemBackground) : Color(.systemGroupedBackground)
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
}

struct RideHistoryRow: View {
    let ride: Ride
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(ride.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(String(format: "%.1f", ride.distance * 0.000621371)) miles")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(String(format: "%.0f", ride.averageSpeed)) mph")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(String(format: "%.0f", ride.duration / 60)) min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct EmergencyContactsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var safetyManager: SafetyManager
    @State private var showingAddContact = false
    @State private var selectedContact: EmergencyContact?
    @State private var showingDeleteAlert = false
    @State private var contactToDelete: EmergencyContact?
    
    var body: some View {
        NavigationView {
            VStack {
                if safetyManager.emergencyContacts.isEmpty {
                    ContentUnavailableView(
                        "No Emergency Contacts",
                        systemImage: "person.3.fill",
                        description: Text("Add emergency contacts to be notified in case of an accident")
                    )
                } else {
                    List {
                        Section(header: Text("Emergency Contacts (\(safetyManager.emergencyContacts.count))")) {
                            ForEach(safetyManager.emergencyContacts) { contact in
                                EmergencyContactRowWithActions(
                                    contact: contact,
                                    onEdit: {
                                        print("🔧 Edit button tapped for contact: \(contact.name)")
                                        selectedContact = contact
                                        print("🔧 selectedContact set to: \(selectedContact?.name ?? "nil")")
                                    },
                                    onDelete: {
                                        contactToDelete = contact
                                        showingDeleteAlert = true
                                    },
                                    onCall: {
                                        callContact(contact)
                                    }
                                )
                            }
                            .onDelete(perform: deleteContacts)
                        }
                        
                        Section(footer: Text("Emergency contacts will be automatically notified if a crash is detected. The primary contact will be called first.")) {
                            EmptyView()
                        }
                    }
                }
            }
            .navigationTitle("Emergency Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showingAddContact = true
                        }) {
                            Label("Add Contact", systemImage: "plus")
                        }
                        
                        if !safetyManager.emergencyContacts.isEmpty {
                            Button(action: {
                                testEmergencyNotification()
                            }) {
                                Label("Test Notifications", systemImage: "bell.badge")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddContact) {
                AddEmergencyContactView()
            }
            .sheet(item: $selectedContact) { contact in
                EditEmergencyContactView(contact: contact)
                    .onAppear {
                        print("✅ EditEmergencyContactView appeared for contact: \(contact.name)")
                    }
            }
            .alert("Delete Contact", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    contactToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let contact = contactToDelete {
                        safetyManager.removeEmergencyContact(contact)
                        contactToDelete = nil
                    }
                }
            } message: {
                if let contact = contactToDelete {
                    Text("Are you sure you want to delete \(contact.name) from your emergency contacts?")
                }
            }
        }
    }
    
    private func deleteContacts(at offsets: IndexSet) {
        for index in offsets {
            let contact = safetyManager.emergencyContacts[index]
            safetyManager.removeEmergencyContact(contact)
        }
    }
    
    private func callContact(_ contact: EmergencyContact) {
        let phoneNumber = contact.phoneNumber.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        
        if let url = URL(string: "tel://\(phoneNumber)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func testEmergencyNotification() {
        // Show confirmation that test notification would be sent
        let alert = UIAlertController(
            title: "Test Emergency Notification",
            message: "This would send a test message to all your emergency contacts letting them know you're testing the system.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Send Test", style: .default) { _ in
            // In a real app, would send actual notifications
            for contact in safetyManager.emergencyContacts {
                print("📱 Test notification sent to \(contact.name): MotoRev emergency system test - please disregard.")
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
}

struct EmergencyContactRowWithActions: View {
    let contact: EmergencyContact
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onCall: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Contact Avatar
            Circle()
                .fill(contact.isPrimary ? Color.red : Color.blue)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(contact.name.prefix(1).uppercased()))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            // Contact Information
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(contact.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if contact.isPrimary {
                        Text("PRIMARY")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
                
                Text(contact.relationship)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(contact.phoneNumber)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .monospacedDigit()
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 8) {
                // Call Button
                Button(action: onCall) {
                    Image(systemName: "phone.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Edit Button
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// EmergencyContactRow is defined in ICEScreenView.swift to avoid duplication

struct AddEmergencyContactView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var safetyManager: SafetyManager
    @State private var name = ""
    @State private var phoneNumber = ""
    @State private var relationship = ""
    @State private var isPrimary = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Contact Information")) {
                    TextField("Name", text: $name)
                        .autocapitalization(.words)
                    
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .autocorrectionDisabled()
                        .onChange(of: phoneNumber) { oldValue, newValue in
                            // Remove any unwanted auto-inserted text
                            if newValue.contains("77764") && !oldValue.contains("77764") {
                                phoneNumber = oldValue
                            }
                        }
                    
                    TextField("Relationship", text: $relationship)
                        .autocapitalization(.words)
                }
                
                Section(header: Text("Settings")) {
                    Toggle("Primary Contact", isOn: $isPrimary)
                        .help("Primary contact will be called first in emergencies")
                }
                
                Section(footer: Text("Emergency contacts will be automatically notified if a crash is detected or you trigger an SOS.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveContact()
                    }
                    .disabled(name.isEmpty || phoneNumber.isEmpty || relationship.isEmpty)
                }
            }
        }
    }
    
    private func saveContact() {
        // If setting as primary, update other contacts first
        if isPrimary {
            for index in safetyManager.emergencyContacts.indices {
                safetyManager.emergencyContacts[index].isPrimary = false
            }
        }
        
        let contact = EmergencyContact(
            id: UUID(),
            name: name,
            phoneNumber: phoneNumber,
            relationship: relationship,
            isPrimary: isPrimary || safetyManager.emergencyContacts.isEmpty // First contact becomes primary automatically
        )
        safetyManager.addEmergencyContact(contact)
        dismiss()
    }
}

struct EditEmergencyContactView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var safetyManager: SafetyManager
    let contact: EmergencyContact
    @State private var name: String
    @State private var phoneNumber: String
    @State private var relationship: String
    @State private var isPrimary: Bool
    
    init(contact: EmergencyContact) {
        self.contact = contact
        self._name = State(initialValue: contact.name)
        self._phoneNumber = State(initialValue: contact.phoneNumber)
        self._relationship = State(initialValue: contact.relationship)
        self._isPrimary = State(initialValue: contact.isPrimary)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Contact Information")) {
                    TextField("Name", text: $name)
                        .autocapitalization(.words)
                    
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .autocorrectionDisabled()
                    
                    TextField("Relationship", text: $relationship)
                        .autocapitalization(.words)
                }
                
                Section(header: Text("Settings")) {
                    Toggle("Primary Contact", isOn: $isPrimary)
                        .help("Primary contact will be called first in emergencies")
                }
                
                Section(footer: Text("Changes will be synchronized across all safety features.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty || phoneNumber.isEmpty || relationship.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        // If setting as primary, update other contacts first
        if isPrimary && !contact.isPrimary {
            for index in safetyManager.emergencyContacts.indices {
                safetyManager.emergencyContacts[index].isPrimary = false
            }
        }
        
        // Update the contact
        var updatedContact = contact
        updatedContact.name = name
        updatedContact.phoneNumber = phoneNumber
        updatedContact.relationship = relationship
        updatedContact.isPrimary = isPrimary
        
        safetyManager.updateEmergencyContact(updatedContact)
        dismiss()
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var safetyManager: SafetyManager
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var crashDetectionManager: CrashDetectionManager
    @EnvironmentObject var locationSharingManager: LocationSharingManager
    
    // Safety Settings
    @State private var crashDetectionEnabled = true
    @State private var autoCallEmergencyEnabled = false
    @State private var shareLocationEnabled = true
    
    // Notification Settings
    @State private var rideRemindersEnabled = true
    @State private var safetyAlertsEnabled = true
    @State private var socialUpdatesEnabled = false
    
    // Privacy Settings
    @State private var publicProfileEnabled = true
    @State private var showRideHistoryEnabled = false
    @State private var locationServicesEnabled = true
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Safety")) {
                    Toggle("Crash Detection", isOn: $crashDetectionEnabled)
                        .onChange(of: crashDetectionEnabled) { _, newValue in
                            if newValue {
                                crashDetectionManager.startMonitoring()
                            } else {
                                crashDetectionManager.stopMonitoring()
                            }
                            UserDefaults.standard.set(newValue, forKey: "crashDetectionEnabled")
                        }
                    
                    Toggle("Auto-Call Emergency", isOn: $autoCallEmergencyEnabled)
                        .onChange(of: autoCallEmergencyEnabled) { _, newValue in
                            safetyManager.autoCallEmergency = newValue
                            UserDefaults.standard.set(newValue, forKey: "autoCallEmergencyEnabled")
                        }
                    
                    Toggle("Share Location", isOn: $shareLocationEnabled)
                        .onChange(of: shareLocationEnabled) { _, newValue in
                            if newValue {
                                locationSharingManager.enableLocationSharing()
                            } else {
                                locationSharingManager.disableLocationSharing()
                            }
                            UserDefaults.standard.set(newValue, forKey: "shareLocationEnabled")
                        }
                }
                
                Section(header: Text("Notifications")) {
                    Toggle("Ride Reminders", isOn: $rideRemindersEnabled)
                        .onChange(of: rideRemindersEnabled) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "rideRemindersEnabled")
                        }
                    
                    Toggle("Safety Alerts", isOn: $safetyAlertsEnabled)
                        .onChange(of: safetyAlertsEnabled) { _, newValue in
                            safetyManager.safetyAlertsEnabled = newValue
                            UserDefaults.standard.set(newValue, forKey: "safetyAlertsEnabled")
                        }
                    
                    Toggle("Social Updates", isOn: $socialUpdatesEnabled)
                        .onChange(of: socialUpdatesEnabled) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "socialUpdatesEnabled")
                        }
                }
                
                Section(header: Text("Privacy")) {
                    Toggle("Public Profile", isOn: $publicProfileEnabled)
                        .onChange(of: publicProfileEnabled) { _, newValue in
                            socialManager.setProfileVisibility(isPublic: newValue)
                            UserDefaults.standard.set(newValue, forKey: "publicProfileEnabled")
                        }
                    
                    Toggle("Show Ride History", isOn: $showRideHistoryEnabled)
                        .onChange(of: showRideHistoryEnabled) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "showRideHistoryEnabled")
                        }
                    
                    Toggle("Location Services", isOn: $locationServicesEnabled)
                        .onChange(of: locationServicesEnabled) { _, newValue in
                            if newValue {
                                locationManager.requestLocationPermission()
                            }
                            UserDefaults.standard.set(newValue, forKey: "locationServicesEnabled")
                        }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("In Memory of Bryce Raiford")
                        Spacer()
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSettings()
            }
        }
    }
    
    private func loadSettings() {
        // Load saved settings from UserDefaults
        crashDetectionEnabled = UserDefaults.standard.bool(forKey: "crashDetectionEnabled") 
        autoCallEmergencyEnabled = UserDefaults.standard.bool(forKey: "autoCallEmergencyEnabled")
        shareLocationEnabled = UserDefaults.standard.object(forKey: "shareLocationEnabled") as? Bool ?? true
        
        rideRemindersEnabled = UserDefaults.standard.object(forKey: "rideRemindersEnabled") as? Bool ?? true
        safetyAlertsEnabled = UserDefaults.standard.object(forKey: "safetyAlertsEnabled") as? Bool ?? true
        socialUpdatesEnabled = UserDefaults.standard.bool(forKey: "socialUpdatesEnabled")
        
        publicProfileEnabled = UserDefaults.standard.object(forKey: "publicProfileEnabled") as? Bool ?? true
        showRideHistoryEnabled = UserDefaults.standard.bool(forKey: "showRideHistoryEnabled")
        locationServicesEnabled = UserDefaults.standard.object(forKey: "locationServicesEnabled") as? Bool ?? true
    }
    
    private func uploadProfileImage(_ image: UIImage) {
        // Convert image to base64 for upload
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            print("❌ Failed to convert image to data")
            return
        }
        
        let base64String = imageData.base64EncodedString()
        
        // Update profile with new image
        socialManager.updateProfile(profilePicture: base64String)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to upload profile image: \(error)")
                    }
                },
                receiveValue: { _ in
                    print("✅ Profile image uploaded successfully")
                }
            )
            .store(in: &cancellables)
    }
}

#Preview {
    ProfileView()
        .environmentObject(SocialManager.shared)
        .environmentObject(SafetyManager.shared)
        .environmentObject(LocationManager.shared)
        .environmentObject(WatchManager.shared)
        .environmentObject(CrashDetectionManager.shared)
        .environmentObject(LocationSharingManager.shared)
} 
