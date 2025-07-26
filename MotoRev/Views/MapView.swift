import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var safetyManager: SafetyManager
    @EnvironmentObject var socialManager: SocialManager
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showingRideControls = false
    @State private var selectedRider: NearbyRider?
    @State private var showingDestinationSearch = false
    @State private var searchText = ""
    @State private var isUserInteracting = false
    @State private var lastUserInteraction = Date()
    
    // Computed property to check if ride is active
    private var isRideActive: Bool {
        return locationManager.rideStartTime != nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main Map using new iOS 17+ API
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
                    MapUserLocationButton()
                    MapCompass()
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
                    
                    HStack {
                        Spacer()
                        
                        // Safety status indicator
                        SafetyStatusIndicator()
                            .padding()
                    }
                    
                    Spacer()
                    
                    // Speed and stats display
                    if isRideActive {
                        RideStatsOverlay()
                            .padding()
                    }
                    
                    // Bottom controls
                    HStack {
                        VStack(spacing: 8) {
                            // Search button
                            Button(action: {
                                showingDestinationSearch = true
                            }) {
                                Image(systemName: "magnifyingglass")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                            
                            // Re-center button
                            Button(action: {
                                recenterMap()
                            }) {
                                Image(systemName: "location.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color.blue.opacity(0.8))
                                    .clipShape(Circle())
                            }
                        }
                        
                        Spacer()
                        
                        // Ride control button
                        Button(action: {
                            toggleRide()
                        }) {
                            VStack {
                                Image(systemName: isRideActive ? "stop.fill" : "play.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                Text(isRideActive ? "End Ride" : "Start Ride")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 80, height: 60)
                            .background(isRideActive ? Color.red : Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Spacer()
                        
                        // Nearby riders button
                        Button(action: {
                            showNearbyRiders()
                        }) {
                            VStack {
                                Image(systemName: "person.3.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                Text("\(locationManager.nearbyRiders.count)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
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
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                            Text("Controls")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .sheet(isPresented: $showingDestinationSearch) {
                DestinationSearchView()
            }
            .sheet(isPresented: $showingRideControls) {
                RideControlsSheet()
            }
            .sheet(item: $selectedRider) { rider in
                RiderDetailView(rider: rider)
            }
        }
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
            locationManager.stopRideTracking()
            safetyManager.stopRide()
        } else {
            // Start ride
            locationManager.startRideTracking()
            safetyManager.startRide()
        }
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
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText, onSearchButtonClicked: search)
                    .padding()
                
                List(searchResults, id: \.placemark.name) { result in
                    Button(action: {
                        selectDestination(result)
                    }) {
                        VStack(alignment: .leading) {
                            Text(result.name ?? "Unknown")
                                .font(.headline)
                            Text(result.placemark.title ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
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
        }
    }
    
    private func search() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let response = response {
                searchResults = response.mapItems
            }
        }
    }
    
    private func selectDestination(_ destination: MKMapItem) {
        let _ = destination.name ?? destination.placemark.title ?? "Selected Location"
        locationManager.calculateRoute(to: destination.placemark.coordinate)
        dismiss()
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



#Preview {
    MapView()
        .environmentObject(LocationManager.shared)
        .environmentObject(SafetyManager.shared)
        .environmentObject(SocialManager.shared)
} 