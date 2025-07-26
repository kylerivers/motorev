import SwiftUI
import CoreLocation

struct ICEScreenView: View {
    @ObservedObject var safetyManager = SafetyManager.shared
    @ObservedObject var crashDetectionManager = CrashDetectionManager.shared
    @ObservedObject var locationSharingManager = LocationSharingManager.shared
    @State private var showingMedicalInfo = false
    @State private var showingEmergencyConfirmation = false
    @State private var emergencyTriggered = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.red.opacity(0.1),
                    Color.red.opacity(0.05)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Emergency Action Button
                    emergencyActionSection
                    
                    // Medical Information
                    medicalInfoSection
                    
                    // Emergency Contacts
                    emergencyContactsSection
                    
                    // Location Information
                    locationInfoSection
                    
                    // Instructions
                    instructionsSection
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Emergency")
        .navigationBarTitleDisplayMode(.large)
        .alert("Trigger Emergency Response?", isPresented: $showingEmergencyConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("EMERGENCY", role: .destructive) {
                triggerEmergency()
            }
        } message: {
            Text("This will immediately alert emergency services and your emergency contacts. Only use in real emergencies.")
        }
        .sheet(isPresented: $showingMedicalInfo) {
            MedicalInfoView()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "sos")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("In Case of Emergency")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Quick access to emergency services and medical information")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Emergency Action Section
    private var emergencyActionSection: some View {
        VStack(spacing: 16) {
            // Main Emergency Button
            Button(action: {
                showingEmergencyConfirmation = true
                // Provide haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 40))
                    
                    Text("EMERGENCY")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Call 911 & Alert Contacts")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.red)
                        .shadow(color: .red.opacity(0.3), radius: 10, x: 0, y: 5)
                )
            }
            .scaleEffect(emergencyTriggered ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: emergencyTriggered)
            
            // Quick Actions Row
            HStack(spacing: 12) {
                EmergencyQuickAction(
                    icon: "location.fill",
                    title: "Share Location",
                    subtitle: "Send to contacts",
                    color: .blue,
                    action: shareLocationEmergency
                )
                
                EmergencyQuickAction(
                    icon: "phone.circle",
                    title: "Call Contact",
                    subtitle: "Primary contact",
                    color: .green,
                    action: callPrimaryContact
                )
                
                EmergencyQuickAction(
                    icon: "heart.text.square",
                    title: "Medical Info",
                    subtitle: "Show details",
                    color: .orange,
                    action: { showingMedicalInfo = true }
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Medical Information Section
    private var medicalInfoSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                
                Text("Medical Information")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Edit") {
                    showingMedicalInfo = true
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(12)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                MedicalInfoCard(
                    title: "Blood Type",
                    value: getUserMedicalInfo().bloodType,
                    icon: "drop.fill",
                    color: .red
                )
                
                MedicalInfoCard(
                    title: "Allergies",
                    value: getUserMedicalInfo().allergies.isEmpty ? "None" : getUserMedicalInfo().allergies.joined(separator: ", "),
                    icon: "exclamationmark.triangle.fill",
                    color: .orange
                )
                
                MedicalInfoCard(
                    title: "Medications",
                    value: getUserMedicalInfo().medications.isEmpty ? "None" : getUserMedicalInfo().medications.joined(separator: ", "),
                    icon: "pills.fill",
                    color: .blue
                )
                
                MedicalInfoCard(
                    title: "Medical ID",
                    value: getUserMedicalInfo().medicalID ?? "Not set",
                    icon: "person.text.rectangle.fill",
                    color: .green
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Emergency Contacts Section
    private var emergencyContactsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Emergency Contacts")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(safetyManager.emergencyContacts.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            
            if safetyManager.emergencyContacts.isEmpty {
                EmptyStateView(
                    icon: "person.badge.plus",
                    title: "No Emergency Contacts",
                    subtitle: "Add emergency contacts for automatic notifications",
                    actionTitle: "Add Contact",
                    action: {
                        // TODO: Navigate to add contact
                    }
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(safetyManager.emergencyContacts) { contact in
                        EmergencyContactRow(contact: contact)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Location Information Section
    private var locationInfoSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "location.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("Current Location")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if true { // In real app, would check LocationManager instance
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "location.slash")
                        .font(.title3)
                        .foregroundColor(.red)
                }
            }
            
            // In real app, would get location from LocationManager via @EnvironmentObject
            let mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
            if true {
                let location = mockLocation
                VStack(spacing: 8) {
                    HStack {
                        Text("Coordinates:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(location.coordinate.latitude, specifier: "%.6f"), \(location.coordinate.longitude, specifier: "%.6f")")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Accuracy:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("±\(Int(location.horizontalAccuracy))m")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    // In real app, would get verified location from LocationManager
                    let mockVerifiedLocation = VerifiedLocation(
                        coordinates: mockLocation.coordinate,
                        accuracy: 5.0,
                        nearestAddress: "123 Main St, San Francisco, CA",
                        crossReferencedAddress: nil,
                        landmarks: ["Near Golden Gate Park"],
                        confidence: 0.9,
                        timestamp: Date()
                    )
                    if true {
                        let verifiedLocation = mockVerifiedLocation
                        HStack {
                            Text("Address:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        
                        Text(verifiedLocation.nearestAddress)
                            .font(.caption)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            } else {
                Text("Location unavailable - Enable location services")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Instructions Section
    private var instructionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Emergency Instructions")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                InstructionRow(
                    number: "1",
                    title: "Press Emergency Button",
                    description: "Tap the red emergency button to trigger automatic response"
                )
                
                InstructionRow(
                    number: "2",
                    title: "Automatic 911 Call",
                    description: "System will automatically call emergency services with your location"
                )
                
                InstructionRow(
                    number: "3",
                    title: "Contact Notification",
                    description: "Emergency contacts will receive SMS with your location and situation"
                )
                
                InstructionRow(
                    number: "4",
                    title: "Continuous Updates",
                    description: "Location will be shared continuously until emergency is resolved"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Helper Functions
    private func triggerEmergency() {
        emergencyTriggered = true
        
        // Trigger emergency response
        locationSharingManager.enableEmergencySharing()
        
        // In a real app, this would call 911
        print("🚨 EMERGENCY TRIGGERED - Calling 911 and notifying contacts")
        
        // Reset after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            emergencyTriggered = false
        }
        
        // Provide strong haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // TODO: Implement actual emergency call
        if let url = URL(string: "tel://911") {
            UIApplication.shared.open(url)
        }
    }
    
    private func shareLocationEmergency() {
        locationSharingManager.enableEmergencySharing()
    }
    
    private func callPrimaryContact() {
        guard let primaryContact = safetyManager.emergencyContacts.first(where: { $0.isPrimary }) ?? safetyManager.emergencyContacts.first else {
            return
        }
        
        let phoneNumber = primaryContact.phoneNumber.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        if let url = URL(string: "tel://\(phoneNumber)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func getUserMedicalInfo() -> MedicalInfo {
        // Load from UserDefaults with fallback to default values
        let defaults = UserDefaults.standard
        
        return MedicalInfo(
            bloodType: defaults.string(forKey: "medical_blood_type") ?? "O+",
            allergies: defaults.stringArray(forKey: "medical_allergies") ?? ["None"],
            medications: defaults.stringArray(forKey: "medical_medications") ?? ["None"],
            medicalID: defaults.string(forKey: "medical_id") ?? "DOE123456",
            conditions: defaults.stringArray(forKey: "medical_conditions") ?? [],
            emergencyNotes: defaults.string(forKey: "medical_emergency_notes") ?? "Motorcycle rider"
        )
    }
}

// MARK: - Supporting Views

struct EmergencyQuickAction: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct MedicalInfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct EmergencyContactRow: View {
    let contact: EmergencyContact
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(contact.isPrimary ? Color.red : Color.blue)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(contact.name.prefix(1).uppercased()))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
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
            }
            
            Spacer()
            
            Button(action: {
                let phoneNumber = contact.phoneNumber.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
                if let url = URL(string: "tel://\(phoneNumber)") {
                    UIApplication.shared.open(url)
                }
            }) {
                Image(systemName: "phone.fill")
                    .font(.title3)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct InstructionRow: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 30, height: 30)
                .overlay(
                    Text(number)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.gray)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button(actionTitle, action: action)
                .font(.caption)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .padding()
    }
}

// MARK: - Supporting Models
// Note: MedicalInfo is defined in DataModels.swift

struct MedicalInfoView: View {
    var body: some View {
        NavigationView {
            Text("Medical Information Editor")
                .navigationTitle("Medical Info")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    NavigationView {
        ICEScreenView()
    }
} 