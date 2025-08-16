import SwiftUI
import MapKit
import CoreLocation
import Combine

struct MapView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var safetyManager: SafetyManager
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var crashDetectionManager: CrashDetectionManager
    @EnvironmentObject var weatherManager: WeatherManager
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showingRideControls = false
    @State private var selectedRider: NearbyRider?
    @State private var showingDestinationSearch = false
    @State private var searchText = ""
    @State private var isUserInteracting = false
    @State private var lastUserInteraction = Date()
    @State private var showPaywall = false
    @State private var showingNearbyRiders = false
    @State private var showingWeatherAlerts = false
    @State private var showingFuelSession = false
    @State private var showingRoutePlanner = false
    @State private var showingJoinRideOptions = false
    @State private var showingRideTypeSelector = false
    @State private var currentRideType: RideType = .none
    @State private var showingRideCompletion = false
    @State private var completedRideData: CompletedRideData?
    @State private var showingActiveRideDetails = false
    
    // Computed property to check if ride is active
    private var isRideActive: Bool {
        return locationManager.rideStartTime != nil
    }
    
    // Computed property for safety status text
    private var safetyStatusText: String {
        switch safetyManager.safetyStatus {
        case .safe:
            return "Safe"
        case .warning:
            return "Caution"
        case .emergency:
            return "Emergency"
        case .crashDetected:
            return "Crash"
        }
    }
    
    // Separate map view to avoid type-checking issues
    private var mapView: some View {
        Map(position: $cameraPosition) {
            // User location annotation
            UserAnnotation()
            
            // Nearby riders annotations
            ForEach(Array(locationManager.nearbyRiders.enumerated()), id: \.element.id) { index, rider in
                Annotation(rider.name, coordinate: rider.location) {
                    SmartRiderAnnotation(
                        rider: rider,
                        shouldShowLabel: shouldShowRiderLabel(for: index, rider: rider)
                    )
                }
            }
            
            // Route overlay if available
            if let route = locationManager.currentRoute {
                MapPolyline(route.polyline)
                    .stroke(.blue, lineWidth: 5)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main Map using new iOS 17+ API
                mapView
            
                
                // Only essential overlays - no redundant buttons
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(safetyManager.safetyStatus == .safe ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(safetyStatusText)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .padding(12)
                }
                .gesture(
                    DragGesture()
                        .onChanged { _ in
                            isUserInteracting = true
                            lastUserInteraction = Date()
                        }
                        .onEnded { _ in
                            // User stops interacting after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                if Date().timeIntervalSince(lastUserInteraction) >= 3.0 {
                                    isUserInteracting = false
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { _ in
                            isUserInteracting = true
                            lastUserInteraction = Date()
                        }
                )
                .onAppear {
                    // Only center map on initial appearance if no destination is set
                    if locationManager.selectedDestination.isEmpty {
                        updateCameraPosition()
                    }
                    locationManager.startLocationUpdates()
                }
                .onDisappear {
                    locationManager.stopLocationUpdates()
                }
                .onChange(of: locationManager.location) { _, newLocation in
                    if let _ = newLocation, !isUserInteracting {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            updateCameraPosition()
                        }
                    }
                }
                
                // Floating controls
                VStack {
                    // Destination display at top
                    if !locationManager.selectedDestination.isEmpty {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Navigating to:")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text(locationManager.selectedDestination)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                locationManager.clearDestination()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    
                    Spacer()
                    
                    // Speed and stats display (when riding)
                    if isRideActive {
                        RideStatsOverlay()
                            .padding()
                    }
                    
                    // Center button - positioned near the map
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                centerMapOnUserLocation()
                            }) {
                                VStack(spacing: 2) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 16))
                                    Text("Center")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .frame(width: 50, height: 50)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .padding(.trailing)
                        }
                        Spacer()
                    }
                    
                    // COMPACT NAVIGATION DOCK - 2x2 + Center + 2x2 Grid
                    HStack(spacing: 12) {
                        // LEFT 2x2 GRID
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                // Weather
                                Button(action: {
                                    showingWeatherAlerts = true
                                }) {
                                    VStack(spacing: 2) {
                                        Image(systemName: weatherManager.currentWeather?.iconName ?? "cloud.fill")
                                            .font(.system(size: 14))
                                        Text("Weather")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    .frame(width: 50, height: 50)
                                    .background(Color.black.opacity(0.7))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                
                                // Fuel
                                Button(action: {
                                    showingFuelSession = true
                                }) {
                                    VStack(spacing: 2) {
                                        Image(systemName: "fuelpump.fill")
                                            .font(.system(size: 14))
                                        Text("Fuel")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    .frame(width: 50, height: 50)
                                    .background(Color.black.opacity(0.7))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                            }
                            
                            HStack(spacing: 8) {
                                // Music
                                NavigationLink(destination: SharedMusicView()
                                    .environmentObject(NowPlayingManager.shared)
                                    .environmentObject(GroupRideManager.shared)
                                ) {
                                    VStack(spacing: 2) {
                                        Image(systemName: "music.note.list")
                                            .font(.system(size: 14))
                                        Text("Music")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    .frame(width: 50, height: 50)
                                    .background(Color.black.opacity(0.7))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                
                                // Voice Assistant
                                Button(action: {
                                    if PremiumManager.shared.isPremium {
                                        if VoiceAssistantManager.shared.isListening {
                                            VoiceAssistantManager.shared.stopListening()
                                        } else {
                                            VoiceAssistantManager.shared.startListening()
                                        }
                                    } else {
                                        showPaywall = true
                                    }
                                }) {
                                    VStack(spacing: 2) {
                                        Image(systemName: VoiceAssistantManager.shared.isListening ? "mic.fill" : "mic")
                                            .font(.system(size: 14))
                                        Text("Voice")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    .frame(width: 50, height: 50)
                                    .background(Color.black.opacity(0.7))
                                    .foregroundColor(VoiceAssistantManager.shared.isListening ? .red : .white)
                                    .cornerRadius(10)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // CENTER - Enhanced Ride Control System
                        RideControlCenterView(
                            isRideActive: isRideActive,
                            currentRideType: getCurrentRideType(),
                            onSoloRide: { startSoloRide() },
                            onGroupRide: { startGroupRide() },
                            onJoinRide: { showJoinRideOptions() },
                            onEndRide: { toggleRide() },
                            showingActiveRideDetails: $showingActiveRideDetails
                        )
                        
                        Spacer()
                        
                        // RIGHT 2x2 GRID
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                // Nearby Riders
                                Button(action: {
                                    showingNearbyRiders = true
                                }) {
                                    VStack(spacing: 2) {
                                        Image(systemName: "person.3.fill")
                                            .font(.system(size: 14))
                                        Text("Riders")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    .frame(width: 50, height: 50)
                                    .background(Color.black.opacity(0.7))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                
                                // Events
                                NavigationLink(destination: RideEventsView()
                                    .environmentObject(NetworkManager.shared)
                                    .environmentObject(SocialManager.shared)
                                    .environmentObject(locationManager)
                                ) {
                                    VStack(spacing: 2) {
                                        Image(systemName: "calendar.badge.plus")
                                            .font(.system(size: 14))
                                        Text("Events")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    .frame(width: 50, height: 50)
                                    .background(Color.black.opacity(0.7))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                            }
                            
                            HStack(spacing: 8) {
                                // Mic/Intercom
                                Button(action: {
                                    if PremiumManager.shared.isPremium {
                                        IntercomManager.shared.toggleMute()
                                    } else {
                                        showPaywall = true
                                    }
                                }) {
                                    VStack(spacing: 2) {
                                        Image(systemName: IntercomManager.shared.isMuted ? "mic.slash.fill" : "mic.fill")
                                            .font(.system(size: 14))
                                        Text("Mic")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    .frame(width: 50, height: 50)
                                    .background(Color.black.opacity(0.7))
                                    .foregroundColor(IntercomManager.shared.isMuted ? .red : .white)
                                    .cornerRadius(10)
                                }
                                
                                // Emergency/SOS
                                Button(action: {
                                    safetyManager.safetyStatus = .emergency
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                                    impactFeedback.impactOccurred()
                                }) {
                                    VStack(spacing: 2) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 14))
                                        Text("SOS")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    .frame(width: 50, height: 50)
                                    .background(Color.red.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Navigate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingRideControls = true
                    }) {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingDestinationSearch) {
                DestinationSearchView()
            }
            .sheet(isPresented: $showingRideControls) {
                RideControlsSheet()
            }
            .sheet(isPresented: $showingNearbyRiders) {
                NearbyRidersView()
            }
            .sheet(isPresented: $showingWeatherAlerts) {
                WeatherAlertsView()
            }
            .sheet(isPresented: $showingFuelSession) {
                FuelFinderView()
            }
            .sheet(isPresented: $showingRoutePlanner) {
                PlanRideView()
            }
            .sheet(isPresented: $showingJoinRideOptions) {
                JoinRideOptionsView()
                    .environmentObject(GroupRideManager.shared)
                    .environmentObject(socialManager)
            }
            .sheet(isPresented: $showingRideCompletion) {
                if let rideData = completedRideData {
                    RideCompletionView(rideData: rideData) {
                        showingRideCompletion = false
                        completedRideData = nil
                    }
                    .environmentObject(socialManager)
                    .environmentObject(NetworkManager.shared)
                }
            }
            .sheet(isPresented: $showingActiveRideDetails) {
                ActiveRideDetailsView()
                    .environmentObject(locationManager)
                    .environmentObject(socialManager)
            }
            .sheet(item: $selectedRider) { rider in
                RiderDetailView(rider: rider)
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }
    
    private func centerMapOnUserLocation() {
        guard let location = locationManager.location else { return }
        
        // Center the map on user's current location
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func updateCameraPosition() {
        // Only update camera if user is not actively interacting with the map
        guard !isUserInteracting else { return }
        
        if let location = locationManager.location {
            cameraPosition = .region(MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }
    
    private func recenterMap() {
        // Force recenter regardless of user interaction state
        isUserInteracting = false
        updateCameraPosition()
    }
    
    private func toggleRide() {
        if isRideActive {
            // Stop ride
            endCurrentRide()
        } else {
            // Start ride
            startNewRide()
        }
    }
    
    private func startNewRide() {
        // Request location permission if needed
        locationManager.requestLocationPermission()
        
        // Start tracking
        locationManager.startRideTracking()
        safetyManager.startRide()
        
        // Start crash detection if enabled
        crashDetectionManager.startMonitoring()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        print("🏍️ Ride started - GPS tracking active")
    }
    
    private func endCurrentRide() {
        // Capture ride data before stopping tracking
        guard let startTime = locationManager.rideStartTime else { return }
        
        let endTime = Date()
        let rideData = CompletedRideData(
            id: UUID().uuidString,
            rideType: currentRideType,
            startTime: startTime,
            endTime: endTime,
            duration: locationManager.currentRideDuration,
            distance: locationManager.currentRideDistance,
            averageSpeed: locationManager.currentRideAverageSpeed,
            maxSpeed: locationManager.currentRideMaxSpeed,
            route: locationManager.routePoints,
            participants: getParticipants(),
            safetyScore: calculateSafetyScore()
        )
        
        // Stop tracking
        locationManager.stopRideTracking()
        safetyManager.stopRide()
        
        // Stop crash detection
        crashDetectionManager.stopMonitoring()
        
        // Reset ride type
        currentRideType = .none
        
        // Haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
        
        // Show completion popup
        completedRideData = rideData
        showingRideCompletion = true
        
        print("🏁 Ride ended - Showing completion summary")
    }
    
    private func getParticipants() -> [RideParticipant] {
        var participants: [RideParticipant] = []
        
        // Add current user
        if let currentUser = socialManager.currentUser {
            participants.append(RideParticipant(
                id: currentUser.id.uuidString,
                username: currentUser.username,
                name: "\(currentUser.firstName ?? "") \(currentUser.lastName ?? "")".trimmingCharacters(in: .whitespaces),
                isCurrentUser: true
            ))
        }
        
        // Add group ride members if applicable
        if currentRideType == .group || currentRideType == .joined,
           let _ = GroupRideManager.shared.currentGroupRide {
            // TODO: Get actual group members from GroupRideManager
            // For now, add placeholder participants
        }
        
        return participants
    }
    
    private func calculateSafetyScore() -> Int {
        // Calculate safety score based on ride data
        var score = 100
        
        // Deduct points for excessive speed
        if locationManager.currentRideMaxSpeed > 80 {
            score -= 10
        }
        
        // Deduct points for very high average speed
        if locationManager.currentRideAverageSpeed > 65 {
            score -= 5
        }
        
        // Add points for longer, safer rides
        let durationHours = locationManager.currentRideDuration / 3600
        if durationHours > 1 && locationManager.currentRideAverageSpeed < 45 {
            score += 5
        }
        
        return max(0, min(100, score))
    }
    
    private func saveRideData() {
        // Save ride metrics to user profile
        let rideData = [
            "distance": locationManager.currentRideDistance,
            "duration": locationManager.currentRideDuration,
            "averageSpeed": locationManager.averageSpeed,
            "maxSpeed": locationManager.maxSpeed,
            "startTime": locationManager.rideStartTime?.timeIntervalSince1970 ?? 0,
            "endTime": Date().timeIntervalSince1970
        ]
        
        // Store locally first
        var rides = UserDefaults.standard.array(forKey: "user_rides") as? [[String: Any]] ?? []
        rides.append(rideData)
        UserDefaults.standard.set(rides, forKey: "user_rides")
        
        // Update profile aggregates
        updateProfileAggregates()
        
        // TODO: Sync to backend
        // NetworkManager.shared.saveRideData(rideData)
    }
    
    private func updateProfileAggregates() {
        let currentTotalMiles = UserDefaults.standard.double(forKey: "profile_total_miles")
        let currentTotalRides = UserDefaults.standard.integer(forKey: "profile_total_rides")
        
        let newTotalMiles = currentTotalMiles + (locationManager.currentRideDistance * 0.000621371) // Convert meters to miles
        let newTotalRides = currentTotalRides + 1
        
        UserDefaults.standard.set(newTotalMiles, forKey: "profile_total_miles")
        UserDefaults.standard.set(newTotalRides, forKey: "profile_total_rides")
        
        print("📊 Profile updated: \(newTotalRides) rides, \(String(format: "%.1f", newTotalMiles)) total miles")
    }
    
    private func showNearbyRiders() {
        // Center map on nearby riders
        if !locationManager.nearbyRiders.isEmpty {
            let coordinates = locationManager.nearbyRiders.map { $0.location }
            let region = MKCoordinateRegion(
                center: coordinates.first!,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            cameraPosition = .region(region)
        }
    }
    
    private func shouldShowRiderLabel(for index: Int, rider: NearbyRider) -> Bool {
        // Simple label collision avoidance - only show labels for first few riders
        // In a real app, this would calculate actual screen positions and distances
        guard let userLocation = locationManager.location else { return true }
        
        // Calculate distance from user
        let distance = CLLocation(latitude: rider.location.latitude, longitude: rider.location.longitude)
            .distance(from: CLLocation(latitude: userLocation.coordinate.latitude, 
                                     longitude: userLocation.coordinate.longitude))
        
        // Always show labels for very close riders (< 500m)
        if distance < 500 { return true }
        
        // For farther riders, only show labels for the first 3 to avoid clutter
        return index < 3
    }
    
    private func extractCoordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        let pointsCount = polyline.pointCount
        let points = polyline.points()
        var coordinates: [CLLocationCoordinate2D] = []
        
        for i in 0..<pointsCount {
            let coordinate = points[i].coordinate
            coordinates.append(coordinate)
        }
        
        return coordinates
    }
}

struct SafetyStatusIndicator: View {
    @EnvironmentObject var safetyManager: SafetyManager
    
    var body: some View {
        HStack {
            Image(systemName: safetyIcon)
                .font(.caption)
                .foregroundColor(safetyColor)
            
            Text(safetyText)
                .font(.caption)
                .foregroundColor(safetyColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.7))
        .cornerRadius(20)
    }
    
    private var safetyIcon: String {
        switch safetyManager.safetyStatus {
        case .safe:
            return "shield.checkered"
        case .warning:
            return "exclamationmark.triangle"
        case .emergency, .crashDetected:
            return "exclamationmark.octagon"
        }
    }
    
    private var safetyColor: Color {
        switch safetyManager.safetyStatus {
        case .safe:
            return .green
        case .warning:
            return .yellow
        case .emergency, .crashDetected:
            return .red
        }
    }
    
    private var safetyText: String {
        switch safetyManager.safetyStatus {
        case .safe:
            return "Safe"
        case .warning:
            return "Caution"
        case .emergency:
            return "Emergency"
        case .crashDetected:
            return "Crash Detected"
        }
    }
}

struct NearbyRidersView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        NavigationView {
            List {
                if locationManager.nearbyRiders.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No Nearby Riders")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Other riders will appear here when you're on a ride")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(Array(locationManager.nearbyRiders.enumerated()), id: \.offset) { index, rider in
                        HStack(spacing: 12) {
                            // Profile avatar
                            ZStack {
                                Circle()
                                    .fill(rider.isRiding ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "person.fill")
                                    .foregroundColor(rider.isRiding ? .green : .gray)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rider.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                
                                if rider.isRiding {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 6, height: 6)
                                        Text("Riding")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                } else {
                                    Text("Parked")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.1f mi", rider.distance))
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(rider.bike)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Nearby Riders")
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

struct RideControlsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var safetyManager: SafetyManager
    @EnvironmentObject var crashDetectionManager: CrashDetectionManager
    @EnvironmentObject var groupRideManager: GroupRideManager
    @EnvironmentObject var weatherManager: WeatherManager
    @State private var showingInviteSheet = false
    @State private var showingDestinationSearch = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Ride Controls") {
                    HStack {
                        Image(systemName: locationManager.rideStartTime != nil ? "stop.circle.fill" : "play.circle.fill")
                            .foregroundColor(locationManager.rideStartTime != nil ? .red : .green)
                        Text(locationManager.rideStartTime != nil ? "End Current Ride" : "Start New Ride")
                        Spacer()
                    }
                    .onTapGesture {
                        // Toggle ride state
                        dismiss()
                    }
                    
                    if locationManager.rideStartTime != nil {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(.blue)
                            Text("Invite Riders")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .onTapGesture {
                            showingInviteSheet = true
                        }
                    }
                }
                
                Section("Safety") {
                    Toggle(isOn: Binding(
                        get: { crashDetectionManager.isMonitoring },
                        set: { enabled in
                            if enabled {
                                crashDetectionManager.startMonitoring()
                            } else {
                                crashDetectionManager.stopMonitoring()
                            }
                        }
                    )) {
                        HStack {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(.green)
                            Text("Crash Detection")
                        }
                    }
                    
                    HStack {
                        Image(systemName: "sos.circle")
                            .foregroundColor(.red)
                        Text("Emergency SOS")
                        Spacer()
                        Button("Test") {
                            // Trigger emergency protocol
                            safetyManager.safetyStatus = .emergency
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section("Communication") {
                    Toggle(isOn: Binding(
                        get: { !IntercomManager.shared.isMuted },
                        set: { enabled in
                            // Only toggle if the current state doesn't match desired state
                            if (enabled && IntercomManager.shared.isMuted) || (!enabled && !IntercomManager.shared.isMuted) {
                                IntercomManager.shared.toggleMute()
                            }
                        }
                    )) {
                        HStack {
                            Image(systemName: "mic.circle")
                                .foregroundColor(.blue)
                            Text("Intercom")
                        }
                    }
                    
                    HStack {
                        Image(systemName: "phone.circle")
                            .foregroundColor(.green)
                        Text("Voice Calls")
                        Spacer()
                        Button("Connect") {
                            VoIPManager.shared.connect()
                        }
                        .foregroundColor(.green)
                    }
                }
                
                Section("Navigation") {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue)
                        Text("Route Search")
                        Spacer()
                        Button("Search") {
                            showingDestinationSearch = true
                        }
                        .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Image(systemName: "map")
                            .foregroundColor(.blue)
                        Text("Map Style")
                        Spacer()
                        Text("Standard")
                            .foregroundColor(.gray)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.orange)
                        Text("Offline Maps")
                        Spacer()
                        if PremiumManager.shared.isPremium {
                                NavigationLink(destination: EnhancedOfflineMapsView()
                                    .environmentObject(locationManager)
                                ) {
                                    Text("Manage")
                                        .foregroundColor(.blue)
                            }
                        } else {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Pro")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                            .onTapGesture {
                                // Show paywall
                                }
                            }
                        }
                        
                        if PremiumManager.shared.isPremium {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(locationManager.offlineMapRegions.count) regions downloaded")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if locationManager.isOfflineModeEnabled {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text("Offline mode active")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                    }
                    
                    HStack {
                        Image(systemName: "location.circle")
                            .foregroundColor(.blue)
                        Text("Advanced Tracking")
                        Spacer()
                        if PremiumManager.shared.isPremium {
                                                    Toggle("", isOn: Binding(
                            get: { LocationSharingManager.shared.sharingMode != .disabled },
                            set: { enabled in
                                if enabled {
                                    LocationSharingManager.shared.enableLocationSharing()
                                } else {
                                    LocationSharingManager.shared.disableLocationSharing()
                                }
                            }
                        ))
                        } else {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Pro")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                            .onTapGesture {
                                // Show paywall
                            }
                        }
                    }
                }
                
                Section("Media") {
                    HStack {
                        Image(systemName: "music.note")
                            .foregroundColor(.purple)
                        VStack(alignment: .leading) {
                            Text(NowPlayingManager.shared.currentTitle ?? "Not Playing")
                                .font(.headline)
                            Text(NowPlayingManager.shared.currentArtist ?? "")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Button(NowPlayingManager.shared.isPlaying ? "Pause" : "Play") {
                            NowPlayingManager.shared.playPause()
                        }
                    }
                }
                
                Section("Weather") {
                    if let weather = weatherManager.currentWeather {
                        HStack {
                            Image(systemName: weather.iconName)
                                .foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text("\(Int(weather.temperature))°F")
                                    .font(.headline)
                                Text(weather.conditions)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            if weather.windSpeed > 15 {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.yellow)
                        Text("Weather Alerts")
                        Spacer()
                        if PremiumManager.shared.isPremium {
                            Toggle("", isOn: $weatherManager.isWeatherAlertsEnabled)
                        } else {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Pro")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                            .onTapGesture {
                                // Show paywall
                            }
                        }
                    }
                }
                
                if !PremiumManager.shared.isPremium {
                    Section("MotoRev Pro") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("Upgrade to Pro")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text("Offline Maps & Navigation")
                                        .font(.subheadline)
                                }
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text("Advanced Weather Alerts")
                                        .font(.subheadline)
                                }
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text("Enhanced Tracking & Analytics")
                                        .font(.subheadline)
                                }
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text("Priority Support")
                                        .font(.subheadline)
                                }
                            }
                            .padding(.leading, 4)
                            
                            Button(action: {
                                // Show paywall
                                dismiss()
                                // Navigate to paywall
                            }) {
                                Text("Upgrade Now")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Ride Controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingInviteSheet) {
                InviteRidersView()
            }
            .sheet(isPresented: $showingDestinationSearch) {
                DestinationSearchView()
            }
        }
    }
}

struct InviteRidersView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var groupRideManager: GroupRideManager
    @EnvironmentObject var socialManager: SocialManager
    @State private var searchText = ""
    
    // Mock data for friends/followers
    private let mockFriends = [
        Friend(id: "1", username: "RiderMike", name: "Mike Johnson", isOnline: true, distance: "2.3 mi"),
        Friend(id: "2", username: "BikerSarah", name: "Sarah Davis", isOnline: false, distance: "5.1 mi"),
        Friend(id: "3", username: "SpeedDemon", name: "Alex Rivera", isOnline: true, distance: "0.8 mi"),
        Friend(id: "4", username: "CruiserJen", name: "Jennifer Smith", isOnline: true, distance: "12.4 mi")
    ]
    
    var filteredFriends: [Friend] {
        if searchText.isEmpty {
            return mockFriends
        }
        return mockFriends.filter { friend in
            friend.name.localizedCaseInsensitiveContains(searchText) ||
            friend.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search friends...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                
                // Friends list
                List {
                    if filteredFriends.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("No Friends Found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Add friends to invite them to ride")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(filteredFriends) { friend in
                            FriendInviteRow(friend: friend) {
                                inviteFriend(friend)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Invite Riders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Friends") {
                        // Navigate to add friends
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func inviteFriend(_ friend: Friend) {
        // Send ride invite (placeholder implementation)
        print("✅ Invite sent to \(friend.name)")
        
        // Show success feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // TODO: Implement actual invite functionality
        // This would call: NetworkManager.shared.sendRideInvite(to: friend.id)
    }
}

struct Friend: Identifiable {
    let id: String
    let username: String
    let name: String
    let isOnline: Bool
    let distance: String
}

struct FriendInviteRow: View {
    let friend: Friend
    let onInvite: () -> Void
    @State private var isInvited = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile picture placeholder
            ZStack {
                Circle()
                    .fill(friend.isOnline ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "person.fill")
                    .foregroundColor(friend.isOnline ? .green : .gray)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("@\(friend.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if friend.isOnline {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Online")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Text(friend.distance + " away")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                if !isInvited {
                    onInvite()
                    isInvited = true
                }
            }) {
                Text(isInvited ? "Invited" : "Invite")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isInvited ? .green : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isInvited ? Color.green.opacity(0.2) : Color.blue)
                    .cornerRadius(8)
            }
            .disabled(isInvited)
        }
        .padding(.vertical, 4)
    }
}

struct RideStatsOverlay: View {
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        HStack(spacing: 20) {
            VStack {
                Text("\(String(format: "%.0f", locationManager.currentSpeed))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("mph")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            VStack {
                Text("\(String(format: "%.1f", locationManager.currentRideDistance * 0.000621371))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("miles")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            VStack {
                Text("\(String(format: "%.0f", locationManager.averageSpeed))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("avg mph")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }
}

struct DestinationSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationManager: LocationManager
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var recentSearches: [String] = []
    
    private let popularDestinations = [
        "Gas Station", "Restaurant", "Hotel", "Hospital", "Motorcycle Dealership", "Coffee Shop"
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText, onSearchButtonClicked: search)
                    .padding()
                
                if isSearching {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Searching...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                if searchResults.isEmpty && !isSearching {
                    // Show recent searches and popular destinations when no results
                    List {
                        if !recentSearches.isEmpty {
                            Section("Recent Searches") {
                                ForEach(recentSearches.prefix(5), id: \.self) { recent in
                                    Button(action: {
                                        searchText = recent
                                        search()
                                    }) {
                                        HStack {
                                            Image(systemName: "clock.arrow.circlepath")
                                                .foregroundColor(.gray)
                                            Text(recent)
                                            Spacer()
                                        }
                                    }
                                    .foregroundColor(.primary)
                                }
                            }
                        }
                        
                        Section("Quick Search") {
                            ForEach(popularDestinations, id: \.self) { destination in
                                Button(action: {
                                    searchText = destination
                                    search()
                                }) {
                                    HStack {
                                        Image(systemName: iconForDestination(destination))
                                            .foregroundColor(.blue)
                                        Text(destination)
                                        Spacer()
                                        Image(systemName: "arrow.up.left")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                } else {
                    // Show search results
                    List(searchResults, id: \.placemark.name) { result in
                        Button(action: {
                            selectDestination(result)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.name ?? "Unknown Location")
                                        .font(.headline)
                                        .lineLimit(1)
                                    Text(result.placemark.title ?? "")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                if let distance = distanceToResult(result) {
                                    Text(distance)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    
                    if searchResults.isEmpty && !searchText.isEmpty && !isSearching {
                        VStack(spacing: 12) {
                            Image(systemName: "location.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("No Results Found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Try a different search term")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Search Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadRecentSearches()
            }
        }
    }
    
    private func search() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        searchResults = []
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        // Bias search results to current location
        if let location = locationManager.location {
            request.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                if let response = response {
                    searchResults = response.mapItems
                    saveRecentSearch(searchText)
                } else {
                    print("Search error: \(error?.localizedDescription ?? "Unknown")")
                }
            }
        }
    }
    
    private func selectDestination(_ destination: MKMapItem) {
        let destinationName = destination.name ?? destination.placemark.title ?? "Selected Location"
        saveRecentSearch(destinationName)
        locationManager.calculateRoute(to: destination.placemark.coordinate)
        dismiss()
    }
    
    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "recent_searches") ?? []
    }
    
    private func saveRecentSearch(_ search: String) {
        var searches = UserDefaults.standard.stringArray(forKey: "recent_searches") ?? []
        
        // Remove if already exists and add to front
        searches.removeAll { $0 == search }
        searches.insert(search, at: 0)
        
        // Keep only last 10 searches
        searches = Array(searches.prefix(10))
        
        UserDefaults.standard.set(searches, forKey: "recent_searches")
        recentSearches = searches
    }
    
    private func iconForDestination(_ destination: String) -> String {
        switch destination.lowercased() {
        case "gas station": return "fuelpump"
        case "restaurant": return "fork.knife"
        case "hotel": return "bed.double"
        case "hospital": return "cross.case"
        case "motorcycle dealership": return "car.2"
        case "coffee shop": return "cup.and.saucer"
        default: return "mappin.circle"
        }
    }
    
    private func distanceToResult(_ result: MKMapItem) -> String? {
        guard let userLocation = locationManager.location else { return nil }
        
        let resultLocation = CLLocation(
            latitude: result.placemark.coordinate.latitude,
            longitude: result.placemark.coordinate.longitude
        )
        
        let distance = userLocation.distance(from: resultLocation)
        let miles = distance * 0.000621371
        
        if miles < 0.1 {
            return "< 0.1 mi"
        } else if miles < 10 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.0f mi", miles)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    let onSearchButtonClicked: () -> Void
    
    var body: some View {
        HStack {
            TextField("Search for places...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit {
                    onSearchButtonClicked()
                }
            
            Button("Search") {
                onSearchButtonClicked()
            }
        }
    }
}

struct SmartRiderAnnotation: View {
    let rider: NearbyRider
    let shouldShowLabel: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Rider icon (always visible)
            ZStack {
                Circle()
                    .fill(rider.isRiding ? Color.red : Color.gray)
                    .frame(width: 30, height: 30)
                
                Image(systemName: "motorcycle")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            // Label (conditionally visible)
            if shouldShowLabel {
                Text(rider.name)
                    .font(.caption)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .animation(.easeInOut(duration: 0.3), value: shouldShowLabel)
            }
        }
    }
}



struct RiderDetailView: View {
    let rider: NearbyRider
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var socialManager: SocialManager
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    VStack(alignment: .leading) {
                        Text(rider.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(rider.bike)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Circle()
                                .fill(rider.isRiding ? Color.green : Color.gray)
                                .frame(width: 10, height: 10)
                            
                            Text(rider.isRiding ? "Currently Riding" : "Offline")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Distance")
                        .font(.headline)
                    
                    Text("\(String(format: "%.1f", rider.distance)) miles away")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                if rider.isRiding {
                    Button(action: {
                        // Request to join ride
                        requestToJoinRide()
                    }) {
                        Text("Request to Join Ride")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                }
                
                Button(action: {
                    // Follow rider
                    followRider()
                }) {
                    Text("Follow Rider")
                        .font(.headline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Rider Details")
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
    
    private func requestToJoinRide() {
        // Implementation for requesting to join ride
        print("Requesting to join ride with \(rider.name)")
    }
    
    private func followRider() {
        // Implementation for following rider
        print("Following rider \(rider.name)")
    }
}

// MARK: - Enhanced Offline Maps View

struct EnhancedOfflineMapsView: View {
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    )
    @State private var isDownloading = false
    @State private var downloadProgress = 0.0
    @State private var selectedRegionIndex: Int?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Offline mode toggle
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Offline Mode", isOn: .init(
                        get: { locationManager.isOfflineModeEnabled },
                        set: { _ in locationManager.toggleOfflineMode() }
                    ))
                    .font(.headline)
                    
                    Text(locationManager.isOfflineModeEnabled ? 
                         "Using downloaded maps when available" : 
                         "Using live maps with internet connection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Current location download
                VStack(alignment: .leading, spacing: 12) {
                    Text("Download Current Area")
                        .font(.headline)
                    
                    if locationManager.location != nil {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Current Location")
                                    .font(.subheadline)
                                Text("Covers ~10 mile radius")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if isDownloading {
                                VStack {
                                    ProgressView(value: downloadProgress)
                                        .frame(width: 60)
                                    Text("\(Int(downloadProgress * 100))%")
                                        .font(.caption)
                                }
                            } else {
                                Button("Download") {
                                    downloadCurrentArea()
                                }
                                .buttonStyle(.borderedProminent)
                                .font(.caption)
                            }
                        }
                    } else {
                        Text("Enable location services to download current area")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Downloaded regions list
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Downloaded Regions")
                            .font(.headline)
                        Spacer()
                        Text("\(locationManager.offlineMapRegions.count) regions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if locationManager.offlineMapRegions.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.system(size: 32))
                                .foregroundColor(.gray)
                            Text("No offline maps downloaded")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Download areas you frequently ride")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        List {
                            ForEach(locationManager.offlineMapRegions.indices, id: \.self) { index in
                                let region = locationManager.offlineMapRegions[index]
                                OfflineRegionRow(
                                    region: region,
                                    index: index,
                                    onDelete: { deleteRegion(at: index) }
                                )
                            }
                        }
                        .frame(height: 200)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Offline Maps")
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
    
    private func downloadCurrentArea() {
        guard let location = locationManager.location else { return }
        
        isDownloading = true
        downloadProgress = 0.0
        
        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        
        locationManager.downloadOfflineMap(for: region) { result in
            DispatchQueue.main.async {
                self.isDownloading = false
                switch result {
                case .success:
                    print("Region downloaded successfully")
                case .failure(let error):
                    print("Download failed: \(error)")
                }
            }
        }
        
        // Simulate download progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            DispatchQueue.main.async {
                self.downloadProgress += 0.02
                if self.downloadProgress >= 1.0 {
                    timer.invalidate()
                }
            }
        }
    }
    
    private func deleteRegion(at index: Int) {
        let region = locationManager.offlineMapRegions[index]
        locationManager.removeOfflineMap(for: region)
    }
}

struct OfflineRegionRow: View {
    let region: MKCoordinateRegion
    let index: Int
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Region \(index + 1)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Lat: \(region.center.latitude, specifier: "%.3f"), Lon: \(region.center.longitude, specifier: "%.3f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("~\(Int(region.span.latitudeDelta * 69)) miles")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Delete") {
                onDelete()
            }
            .foregroundColor(.red)
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Ride Type System

enum RideType: String, CaseIterable {
    case none = "None"
    case solo = "Solo"
    case group = "Group"
    case joined = "Joined"
    
    var icon: String {
        switch self {
        case .none: return "play.fill"
        case .solo: return "person.fill"
        case .group: return "person.3.fill"
        case .joined: return "person.2.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .none: return .blue
        case .solo: return .green
        case .group: return .purple
        case .joined: return .orange
        }
    }
    
    var description: String {
        switch self {
        case .none: return "Start a ride"
        case .solo: return "Riding solo"
        case .group: return "Leading group"
        case .joined: return "In group ride"
        }
    }
}

// MARK: - Enhanced Ride Control Center

struct RideControlCenterView: View {
    let isRideActive: Bool
    let currentRideType: RideType
    let onSoloRide: () -> Void
    let onGroupRide: () -> Void
    let onJoinRide: () -> Void
    let onEndRide: () -> Void
    @Binding var showingActiveRideDetails: Bool
    
    @State private var showingRideTypeSelector = false
    
    var body: some View {
        if isRideActive {
            // Active ride button - show details and end ride option
            Menu {
                Button("View Details") {
                    showingActiveRideDetails = true
                }
                
                Button("End Ride", role: .destructive) {
                    onEndRide()
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: currentRideType.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("Active")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(currentRideType.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(width: 70, height: 70)
                .background(
                    Circle()
                        .fill(LinearGradient(colors: [currentRideType.color, currentRideType.color.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
            }
        } else {
            // Start ride button with type selection
            Button(action: {
                showingRideTypeSelector = true
            }) {
                VStack(spacing: 2) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("Start")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Ride")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(width: 70, height: 70)
                .background(
                    Circle()
                        .fill(LinearGradient(colors: [.green, .blue], startPoint: .top, endPoint: .bottom))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
            }
            .sheet(isPresented: $showingRideTypeSelector) {
                RideTypeSelectorView(
                    onSoloRide: onSoloRide,
                    onGroupRide: onGroupRide,
                    onJoinRide: onJoinRide
                )
            }
        }
    }
}

// MARK: - Ride Type Selector

struct RideTypeSelectorView: View {
    let onSoloRide: () -> Void
    let onGroupRide: () -> Void
    let onJoinRide: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var groupRideManager: GroupRideManager
    @State private var showingCreateGroup = false
    @State private var showingJoinGroup = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "figure.motorcycle")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Choose Your Ride Type")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Select how you'd like to ride today")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                VStack(spacing: 16) {
                    // Solo Ride
                    RideTypeOptionView(
                        icon: "person.fill",
                        title: "Solo Ride",
                        subtitle: "Track your ride independently",
                        color: .green,
                        action: {
                            dismiss()
                            onSoloRide()
                        }
                    )
                    
                    // Group Ride
                    RideTypeOptionView(
                        icon: "person.3.fill",
                        title: "Create Group Ride",
                        subtitle: "Lead a group and invite friends",
                        color: .purple,
                        action: {
                            dismiss()
                            onGroupRide()
                        }
                    )
                    
                    // Join Ride
                    RideTypeOptionView(
                        icon: "person.2.fill",
                        title: "Join Existing Ride",
                        subtitle: "Find and join nearby group rides",
                        color: .orange,
                        action: {
                            dismiss()
                            onJoinRide()
                        }
                    )
                }
                
                Spacer()
                
                // Social features preview
                if let currentUser = socialManager.currentUser {
                    VStack(spacing: 8) {
                        Text("Riding as")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            AsyncImage(url: URL(string: currentUser.profilePictureUrl ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                            
                            Text(currentUser.username)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("Start Ride")
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

struct RideTypeOptionView: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.1))
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - MapView Extensions

extension MapView {
    private func getCurrentRideType() -> RideType {
        return currentRideType
    }
    
    private func startSoloRide() {
        currentRideType = .solo
        locationManager.startRide()
        
        // Track solo ride in social manager
        socialManager.createPost(
            content: "🏍️ Starting a solo ride! #SoloRide #MotoRev",
            location: locationManager.location?.coordinate,
            rideData: RideData(
                distance: 0,
                duration: 0,
                averageSpeed: 0,
                maxSpeed: 0,
                safetyScore: 100
            )
        )
    }
    
    private func startGroupRide() {
        currentRideType = .group
        locationManager.startRide()
        
        // Show group creation interface
        GroupRideManager.shared.createGroupRide(
            name: "Group Ride - \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short))",
            description: "Join me for a ride!",
            isPrivate: false
        ) { result in
            switch result {
            case .success:
                print("Group ride created successfully")
            case .failure(let error):
                print("Failed to create group ride: \(error)")
            }
        }
        
        // Create social post
        socialManager.createPost(
            content: "🏍️ Starting a group ride! Who wants to join? #GroupRide #MotoRev",
            location: locationManager.location?.coordinate,
            rideData: RideData(
                distance: 0,
                duration: 0,
                averageSpeed: 0,
                maxSpeed: 0,
                safetyScore: 100
            )
        )
    }
    
    private func showJoinRideOptions() {
        showingJoinRideOptions = true
    }
    
    private func joinExistingRide() {
        currentRideType = .joined
        locationManager.startRide()
        
        // TODO: Show available rides to join
        // For now, start tracking and update social
        socialManager.createPost(
            content: "🏍️ Joined a group ride! Let's ride together! #JoinedRide #MotoRev",
            location: locationManager.location?.coordinate,
            rideData: RideData(
                distance: 0,
                duration: 0,
                averageSpeed: 0,
                maxSpeed: 0,
                safetyScore: 100
            )
        )
    }
}

// MARK: - Join Ride Options View

struct JoinRideOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var groupRideManager: GroupRideManager
    @EnvironmentObject var socialManager: SocialManager
    @State private var availableRides: [GroupRide] = []
    @State private var isLoading = true
    @State private var selectedRide: GroupRide?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("Join a Ride")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Find nearby group rides to join")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Available rides list
                Group {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Finding nearby rides...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxHeight: .infinity)
                    } else if availableRides.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.3.sequence")
                                .font(.system(size: 32))
                                .foregroundColor(.gray)
                            
                            Text("No Rides Available")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Be the first to create a group ride!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button("Create Group Ride") {
                                dismiss()
                                // TODO: Trigger group ride creation
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(availableRides) { ride in
                                    RideOptionCard(
                                        ride: ride,
                                        onJoin: {
                                            joinRide(ride)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Join Ride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadAvailableRides()
        }
    }
    
    private func loadAvailableRides() {
        isLoading = true
        
        // Simulate loading available rides
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // TODO: Replace with actual API call to get nearby group rides
            self.availableRides = [
                GroupRide(
                    id: "1",
                    name: "Weekend Mountain Ride",
                    description: "Scenic mountain routes and great views!",
                    leaderId: "user1",
                    leaderUsername: "RiderBob",
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    startedAt: nil,
                    endedAt: nil,
                    status: "pending",
                    memberCount: 3,
                    maxMembers: 8,
                    isPrivate: false,
                    inviteCode: nil
                ),
                GroupRide(
                    id: "2",
                    name: "City Tour Ride",
                    description: "Exploring the city's best motorcycle routes",
                    leaderId: "user2", 
                    leaderUsername: "CityRider",
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    startedAt: nil,
                    endedAt: nil,
                    status: "pending",
                    memberCount: 2,
                    maxMembers: 6,
                    isPrivate: false,
                    inviteCode: nil
                )
            ]
            self.isLoading = false
        }
    }
    
    private func joinRide(_ ride: GroupRide) {
        groupRideManager.joinGroupRide(ride.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Create social post about joining
                    socialManager.createPost(
                        content: "🏍️ Joined '\(ride.name)' group ride! Let's ride together! #GroupRide #MotoRev",
                        location: nil,
                        rideData: RideData(
                            distance: 0,
                            duration: 0,
                            averageSpeed: 0,
                            maxSpeed: 0,
                            safetyScore: 100
                        )
                    )
                    dismiss()
                case .failure(let error):
                    print("Failed to join ride: \(error)")
                }
            }
        }
    }
}

struct RideOptionCard: View {
    let ride: GroupRide
    let onJoin: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ride.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Led by \(ride.leaderUsername)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(ride.memberCount)/\(ride.maxMembers ?? 0)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                    
                    Text(ride.status == "pending" ? "Starting soon" : "Active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let description = ride.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "person.3")
                        .font(.caption)
                    Text("Group Ride")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Join Ride") {
                    onJoin()
                }
                .buttonStyle(.borderedProminent)
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

}



// MARK: - Ride Completion View

struct RideCompletionView: View {
    let rideData: CompletedRideData
    let onDismiss: () -> Void
    
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var networkManager: NetworkManager
    @State private var isSaving = false
    @State private var showingShareSheet = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Ride Completed!")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack {
                        Image(systemName: rideData.rideType.icon)
                            .foregroundColor(rideData.rideType.color)
                        Text(rideData.rideType.rawValue + " Ride")
                            .font(.headline)
                            .foregroundColor(rideData.rideType.color)
                    }
                }
                
                // Ride Stats
                VStack(spacing: 16) {
                    HStack(spacing: 32) {
                        RideStatCard(
                            title: "Distance",
                            value: String(format: "%.1f mi", rideData.distanceInMiles),
                            icon: "road.lanes",
                            color: .blue
                        )
                        
                        RideStatCard(
                            title: "Duration",
                            value: rideData.formattedDuration,
                            icon: "clock",
                            color: .orange
                        )
                    }
                    
                    HStack(spacing: 32) {
                        RideStatCard(
                            title: "Avg Speed",
                            value: String(format: "%.0f mph", rideData.averageSpeed),
                            icon: "speedometer",
                            color: .green
                        )
                        
                        RideStatCard(
                            title: "Max Speed",
                            value: String(format: "%.0f mph", rideData.maxSpeed),
                            icon: "gauge.high",
                            color: .red
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                // Safety Score
                VStack(spacing: 8) {
                    Text("Safety Score")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(safetyScoreColor)
                        Text("\(rideData.safetyScore)/100")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(safetyScoreColor)
                    }
                    
                    Text(safetyScoreText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(safetyScoreColor.opacity(0.1))
                .cornerRadius(12)
                
                // Participants
                if rideData.participants.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ride Participants")
                            .font(.headline)
                        
                        ForEach(rideData.participants) { participant in
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.blue)
                                Text(participant.username)
                                    .fontWeight(participant.isCurrentUser ? .bold : .regular)
                                if participant.isCurrentUser {
                                    Text("(You)")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button("Share Ride") {
                        showingShareSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    
                    Button("View Details") {
                        // TODO: Navigate to detailed ride view
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .navigationTitle("Ride Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .disabled(isSaving)
                }
            }
        }
        .onAppear {
            saveRideToBackend()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [shareText])
        }
    }
    
    private var safetyScoreColor: Color {
        switch rideData.safetyScore {
        case 90...100: return .green
        case 70...89: return .orange
        default: return .red
        }
    }
    
    private var safetyScoreText: String {
        switch rideData.safetyScore {
        case 90...100: return "Excellent riding!"
        case 70...89: return "Good riding"
        default: return "Room for improvement"
        }
    }
    
    private var shareText: String {
        "Just completed a \(rideData.rideType.rawValue.lowercased()) ride! 🏍️\n" +
        "📍 \(String(format: "%.1f", rideData.distanceInMiles)) miles in \(rideData.formattedDuration)\n" +
        "⚡ Max speed: \(String(format: "%.0f", rideData.maxSpeed)) mph\n" +
        "🛡️ Safety score: \(rideData.safetyScore)/100\n" +
        "#MotoRev #MotorcycleRiding"
    }
    
    private func saveRideToBackend() {
        isSaving = true
        
        // Prepare ride data for backend using proper Codable models
        let request = SaveCompletedRideRequest(
            rideId: rideData.id,
            rideType: rideData.rideType.rawValue,
            startTime: ISO8601DateFormatter().string(from: rideData.startTime),
            endTime: ISO8601DateFormatter().string(from: rideData.endTime),
            duration: rideData.duration,
            distance: rideData.distance,
            averageSpeed: rideData.averageSpeed,
            maxSpeed: rideData.maxSpeed,
            route: rideData.route.map { ["lat": $0.coordinate.latitude, "lng": $0.coordinate.longitude] },
            participants: rideData.participants.map { 
                SaveCompletedRideParticipant(
                    id: $0.id, 
                    username: $0.username, 
                    name: $0.name, 
                    isCurrentUser: $0.isCurrentUser
                ) 
            },
            safetyScore: rideData.safetyScore
        )
        
        // Save ride to backend using NetworkManager
        print("🔄 Saving ride to backend: \(rideData.id)")
        print("📊 Ride data: \(rideData.distanceInMiles) miles, \(rideData.formattedDuration), safety: \(rideData.safetyScore)")
        
        networkManager.saveCompletedRide(request)
            .sink(receiveCompletion: { completion in
                DispatchQueue.main.async {
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        print("❌ Failed to save ride to backend: \(error)")
                        print("❌ Error details: \(error.localizedDescription)")
                        self.isSaving = false
                    }
                }
            }, receiveValue: { response in
                DispatchQueue.main.async {
                    print("✅ Ride saved to backend successfully: \(response.message ?? "No message")")
                    
                    // Create social post
                    self.socialManager.createPost(
                        content: "🏍️ Just completed a \(self.rideData.rideType.rawValue.lowercased()) ride! \(String(format: "%.1f", self.rideData.distanceInMiles)) miles in \(self.rideData.formattedDuration). Safety score: \(self.rideData.safetyScore)/100 🛡️ #MotoRev",
                        location: self.rideData.route.last?.coordinate,
                        rideData: RideData(
                            distance: self.rideData.distance,
                            duration: self.rideData.duration,
                            averageSpeed: self.rideData.averageSpeed,
                            maxSpeed: self.rideData.maxSpeed,
                            safetyScore: self.rideData.safetyScore
                        )
                    )
                    
                    self.isSaving = false
                }
            })
            .store(in: &cancellables)
    }
}

struct RideStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Active Ride Details View

struct ActiveRideDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var socialManager: SocialManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Stats
                    VStack(spacing: 16) {
                        Text("Current Ride")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 24) {
                            LiveStatCard(
                                title: "Time",
                                value: formatDuration(locationManager.currentRideDuration),
                                icon: "clock.fill",
                                color: .blue
                            )
                            
                            LiveStatCard(
                                title: "Distance",
                                value: String(format: "%.1f mi", locationManager.currentRideDistance * 0.000621371),
                                icon: "road.lanes",
                                color: .green
                            )
                        }
                        
                        HStack(spacing: 24) {
                            LiveStatCard(
                                title: "Current Speed",
                                value: String(format: "%.0f mph", locationManager.currentRideSpeed),
                                icon: "speedometer",
                                color: .orange
                            )
                            
                            LiveStatCard(
                                title: "Max Speed",
                                value: String(format: "%.0f mph", locationManager.currentRideMaxSpeed),
                                icon: "gauge.high",
                                color: .red
                            )
                        }
                        
                        LiveStatCard(
                            title: "Average Speed",
                            value: String(format: "%.0f mph", locationManager.currentRideAverageSpeed),
                            icon: "dial.low",
                            color: .purple
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    // Ride Controls
                    VStack(spacing: 12) {
                        Text("Ride Controls")
                            .font(.headline)
                        
                        if locationManager.isRidePaused {
                            Button("Resume Ride") {
                                locationManager.resumeRideTracking()
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                        } else {
                            Button("Pause Ride") {
                                locationManager.pauseRideTracking()
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Ride Details")
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
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration.truncatingRemainder(dividingBy: 3600)) / 60
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

struct LiveStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    MapView()
        .environmentObject(LocationManager.shared)
        .environmentObject(SafetyManager.shared)
        .environmentObject(SocialManager.shared)
} 