import SwiftUI
import MapKit

struct ContentView: View {
    @EnvironmentObject var safetyManager: SafetyManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var watchManager: WatchManager
    @ObservedObject var crashDetectionManager = CrashDetectionManager.shared
    @ObservedObject var locationSharingManager = LocationSharingManager.shared
    
    @State private var selectedTab = 0
    @State private var showingICEScreen = false
    @State private var showingWeatherAlerts = false
    @State private var showingFuelFinder = false
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Home - Revitalized Hub with integrated social
                RideHubView(selectedTab: $selectedTab)
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                    .tag(0)
                
                // Navigate - GPS, routes, weather
                NavigationView {
                    VStack {
                        // Main map view
                        MapView()
                        
                        // Navigation quick actions
                        HStack(spacing: 20) {
                            Button(action: { showingWeatherAlerts = true }) {
                                VStack {
                                    Image(systemName: "cloud.rain.fill")
                                    Text("Weather")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                            }
                            
                            Button(action: { showingFuelFinder = true }) {
                                VStack {
                                    Image(systemName: "fuelpump.fill")
                                    Text("Fuel")
                                        .font(.caption)
                                }
                                .foregroundColor(.orange)
                            }
                            
                            Button(action: { }) {
                                VStack {
                                    Image(systemName: "location.circle.fill")
                                    Text("Routes")
                                        .font(.caption)
                                }
                                .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                    }
                }
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Navigate")
                }
                .tag(1)
                
                // Garage - Bike management & maintenance
                DigitalGarageView()
                    .tabItem {
                        Image(systemName: "car.circle.fill")
                        Text("Garage")
                    }
                    .tag(2)
                
                // Safety - Crash detection, emergency features
                NavigationView {
                    SafetyView()
                }
                .tabItem {
                    Image(systemName: "shield.checkered")
                    Text("Safety")
                }
                .tag(3)
                
                // Profile - User profile and account
                NavigationView {
                    ProfileView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("ICE") {
                                    showingICEScreen = true
                                }
                                .foregroundColor(.red)
                                .fontWeight(.bold)
                            }
                        }
                }
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Profile")
                }
                .badge(socialManager.unreadNotificationsCount > 0 ? "\(socialManager.unreadNotificationsCount)" : nil)
                .tag(4)
            }
            .accentColor(.blue)
            
            // Global Emergency Alert Overlay
            EmergencyAlertOverlay()
        }
        .onAppear {
            initializeMotoRevV3()
        }
        .sheet(isPresented: $showingICEScreen) {
            NavigationView {
                ICEScreenView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") {
                                showingICEScreen = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingWeatherAlerts) {
            NavigationView {
                WeatherAlertsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") {
                                showingWeatherAlerts = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingFuelFinder) {
            NavigationView {
                FuelFinderView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") {
                                showingFuelFinder = false
                            }
                        }
                    }
            }
        }
    }
    
    private func initializeMotoRevV3() {
        // Initialize core features
        crashDetectionManager.startMonitoring()
        locationManager.requestLocationPermission()
        socialManager.refreshSocialFeed()
    }
}

// MARK: - Safety View
struct SafetyView: View {
    @EnvironmentObject var safetyManager: SafetyManager
    @ObservedObject var crashDetectionManager = CrashDetectionManager.shared
    @State private var showingICEScreen = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Crash Detection Status
                VStack(spacing: 16) {
                    Image(systemName: crashDetectionManager.isMonitoring ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .font(.system(size: 50))
                        .foregroundColor(crashDetectionManager.isMonitoring ? .green : .red)
                    
                    Text(crashDetectionManager.isMonitoring ? "Crash Detection Active" : "Crash Detection Inactive")
                        .font(.title2)
                        .fontWeight(.bold)
                    
        if !crashDetectionManager.isMonitoring {
                        Button("Enable Protection") {
            crashDetectionManager.startMonitoring()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // Emergency Profile
                VStack(spacing: 12) {
                    Text("Emergency Profile")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Button("View ICE Profile") {
                        showingICEScreen = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // Emergency Contacts
                VStack(alignment: .leading, spacing: 12) {
                    Text("Emergency Contacts")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
        if safetyManager.emergencyContacts.isEmpty {
                        Text("No emergency contacts added")
                            .foregroundColor(.secondary)
        } else {
                        ForEach(safetyManager.emergencyContacts) { contact in
                            Text(contact.name)
                                .padding(.vertical, 4)
    }
                    }
                    
                    Button("Manage Contacts") {
                        // Navigate to emergency contacts
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Safety")
        .sheet(isPresented: $showingICEScreen) {
            NavigationView {
                ICEScreenView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") {
                                showingICEScreen = false
    }
}
                    }
            }
        }
    }
}



// MARK: - Shake Gesture Extension
extension UIDevice {
    static let deviceDidShakeNotification = Foundation.Notification.Name(rawValue: "deviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
    }
}

struct DeviceShakeViewModifier: ViewModifier {
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
                action()
            }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(DeviceShakeViewModifier(action: action))
    }
} 