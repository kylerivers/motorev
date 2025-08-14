import SwiftUI
import CoreLocation
import CoreMotion
import MapKit
import WatchConnectivity
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        _ = NetworkManager.shared.registerPushToken(token)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error)")
    }
}

@main
struct MotoRevApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var bikeManager = BikeManager.shared
    @StateObject private var safetyManager = SafetyManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var socialManager = SocialManager.shared
    @StateObject private var groupRideManager = GroupRideManager.shared
    @StateObject private var watchManager = WatchManager.shared
    @StateObject private var crashDetectionManager = CrashDetectionManager.shared
    @StateObject private var locationSharingManager = LocationSharingManager.shared
    @StateObject private var weatherManager = WeatherManager.shared
    @State private var showingWelcomeAlert = false
    @State private var isInitializing = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isInitializing {
                    // Simple loading screen
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(.systemBackground),
                                Color.red.opacity(0.1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                        
                        VStack(spacing: 30) {
                            // App icon - use actual MotoRev logo
                            ZStack {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 100, height: 100)
                                
                                // Use the actual MotoRev logo if available, fallback to custom design
                                if let logoImage = UIImage(named: "MotoRevLogo") {
                                    Image(uiImage: logoImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else {
                                    // Temporary: Create a motorcycle-themed logo using SF Symbols
                                    ZStack {
                                        // Background speedometer
                                        Image(systemName: "speedometer")
                                            .font(.system(size: 40, weight: .medium))
                                            .foregroundColor(.white.opacity(0.3))
                                        
                                        // Front motorcycle icon
                                        Image(systemName: "motorcycle")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            
                            VStack(spacing: 8) {
                                Text("MotoRev")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                
                                Text("AI-Powered Motorcycle Safety")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.2)
                        }
                    }
                    .transition(.opacity)
                } else {
                    if networkManager.isLoggedIn {
                        ContentView()
                            .environmentObject(networkManager)
                            .environmentObject(bikeManager)
                            .environmentObject(safetyManager)
                            .environmentObject(locationManager)
                            .environmentObject(socialManager)
                            .environmentObject(groupRideManager)
                            .environmentObject(watchManager)
                            .environmentObject(crashDetectionManager)
                            .environmentObject(locationSharingManager)
                            .environmentObject(weatherManager)
                            .environmentObject(VoiceAssistantManager.shared)
                            .environmentObject(IntercomManager.shared)
                            .environmentObject(AIRideAssistantManager.shared)
                            .environmentObject(PremiumManager.shared)
                            .environmentObject(NowPlayingManager.shared)
                            .environmentObject(PushManager.shared)
                            .environmentObject(NFCAddManager.shared)
                            .transition(.opacity)
                    } else {
                        AuthenticationView()
                            .environmentObject(networkManager)
                            .transition(.opacity)
                    }
                }
            }
            .onAppear {
                if isInitializing {
                    initializeApp()
                }
                PushManager.shared.requestAuthorization()
            }
                .alert("Welcome to MotoRev!", isPresented: $showingWelcomeAlert) {
                    Button("Get Started") {
                        showingWelcomeAlert = false
                        setupPermissions()
                    }
                    Button("Maybe Later") {
                        showingWelcomeAlert = false
                    }
                } message: {
                    Text("The ultimate motorcycle safety and social platform. Stay connected, stay safe, and ride with confidence!")
                }
        }
    }
    

    
    private func initializeApp() {
        print("🚀 MotoRev V5 launching...")
        
        // Initialize AI safety systems with delay to prevent crash
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.crashDetectionManager.startMonitoring()
            print("🛡️ Crash detection initialized")
        }
        
        // Show loading screen for 3 seconds minimum
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 0.8)) {
                self.isInitializing = false
            }
            
            print("✅ MotoRev V5 ready with AI-powered safety")
            
            // Check if first launch after loading completes
            if self.isFirstLaunch() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.showingWelcomeAlert = true
                }
            } else {
                self.setupPermissions()
            }
        }
    }
    
    private func isFirstLaunch() -> Bool {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if !hasLaunchedBefore {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            return true
        }
        return false
    }
    
    private func setupPermissions() {
        // Delay permission requests to ensure app is fully loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Request location permissions
            self.locationManager.requestLocationPermission()
            
            // Safety manager handles its own setup automatically
            self.safetyManager.startMonitoring()
        }
    }
} 