import SwiftUI
import CoreLocation

struct DataControlPanelView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var groupManager: GroupRideManager
    @EnvironmentObject var socialManager: SocialManager
    
    @AppStorage("publicProfileEnabled") private var publicProfileEnabled: Bool = true
    @AppStorage("socialUpdatesEnabled") private var socialUpdatesEnabled: Bool = true
    @AppStorage("showRideHistoryEnabled") private var showRideHistoryEnabled: Bool = true
    @AppStorage("locationServicesEnabled") private var locationServicesEnabled: Bool = true
    @AppStorage("crashAlertsEnabled") private var crashAlertsEnabled: Bool = true
    @AppStorage("weatherAlertsEnabled") private var weatherAlertsEnabled: Bool = true
    
    var body: some View {
        Form {
            Section(header: Text("Privacy")) {
                Toggle("Public Profile", isOn: $publicProfileEnabled)
                    .onChange(of: publicProfileEnabled) { _, newValue in
                        socialManager.setProfileVisibility(isPublic: newValue)
                    }
                Toggle("Stealth Mode (no location sharing)", isOn: .init(
                    get: { groupManager.isStealthModeEnabled },
                    set: { groupManager.isStealthModeEnabled = $0 }
                ))
            }
            
            Section(header: Text("Location & Sharing")) {
                Toggle("Location Services", isOn: $locationServicesEnabled)
                    .onChange(of: locationServicesEnabled) { _, newValue in
                        if newValue { locationManager.requestLocationPermission() }
                    }
                Toggle("Show Ride History", isOn: $showRideHistoryEnabled)
            }
            
            Section(header: Text("Notifications")) {
                Toggle("Crash Alerts", isOn: $crashAlertsEnabled)
                Toggle("Weather Alerts", isOn: $weatherAlertsEnabled)
                Toggle("Social Updates", isOn: $socialUpdatesEnabled)
            }
        }
        .navigationTitle("Data Control Panel")
    }
}

#Preview {
    DataControlPanelView()
        .environmentObject(LocationManager.shared)
        .environmentObject(GroupRideManager.shared)
        .environmentObject(SocialManager.shared)
} 