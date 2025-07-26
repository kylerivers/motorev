import SwiftUI
import MapKit
import CoreLocation
import AVFoundation

struct RideNavigationView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var groupRideManager: GroupRideManager
    @Environment(\.dismiss) private var dismiss
    
    let destination: CLLocationCoordinate2D
    let destinationName: String
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var currentInstruction: String = "Starting navigation..."
    @State private var distanceToNextTurn: String = ""
    @State private var estimatedArrival: String = ""
    @State private var routeProgress: Double = 0.0
    @State private var isVoiceEnabled = true
    @State private var showingGroupPanel = false
    @State private var selectedMapStyle: MapStyle = .standard(elevation: .realistic)
    @State private var mapStyleIndex = 0
    
    // Voice synthesis
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        ZStack {
            // Full screen map
            Map(position: $cameraPosition) {
                // User location with direction indicator
                UserAnnotation()
                
                // Destination marker
                Annotation(destinationName, coordinate: destination, anchor: .bottom) {
                    VStack {
                        Image(systemName: "flag.checkered")
                            .font(.title2)
                            .foregroundColor(.green)
                            .padding(8)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                        Text(destinationName)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(8)
                    }
                }
                
                // Current route
                if let route = locationManager.currentRoute {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 6)
                }
                
                // Group ride members if active
                if groupRideManager.isInGroupRide {
                    ForEach(groupRideManager.groupMembers, id: \.id) { member in
                        if let memberLocation = member.lastLocation {
                            let memberCoordinate = CLLocationCoordinate2D(
                                latitude: memberLocation.latitude,
                                longitude: memberLocation.longitude
                            )
                            let memberName = [member.firstName, member.lastName]
                                .compactMap { $0 }
                                .joined(separator: " ")
                            let displayName = memberName.isEmpty ? member.username : memberName
                            
                            Annotation(displayName, coordinate: memberCoordinate) {
                                EnhancedGroupMemberAnnotation(member: member)
                            }
                        }
                    }
                }
                
                // Shared route from group leader
                if let sharedRoute = groupRideManager.sharedRoute {
                    ForEach(sharedRoute.waypoints.sorted(by: { $0.order < $1.order }), id: \.id) { waypoint in
                        Annotation(waypoint.name ?? "Waypoint", coordinate: CLLocationCoordinate2D(latitude: waypoint.latitude, longitude: waypoint.longitude)) {
                            SharedWaypointAnnotation(waypoint: waypoint)
                        }
                    }
                }
                
                // Waypoints
                ForEach(Array(locationManager.routeWaypoints.enumerated()), id: \.offset) { index, waypoint in
                    Annotation("Waypoint \(index + 1)", coordinate: CLLocationCoordinate2D(latitude: waypoint.latitude, longitude: waypoint.longitude)) {
                        WaypointAnnotation(waypoint: waypoint, index: index)
                    }
                }
            }
            .mapStyle(selectedMapStyle)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .onAppear {
                updateCameraPosition()
                startNavigation()
            }
            
            // Navigation overlay UI
            VStack {
                // Top instruction panel
                NavigationInstructionPanel(
                    instruction: currentInstruction,
                    distanceToTurn: distanceToNextTurn,
                    estimatedArrival: estimatedArrival,
                    routeProgress: routeProgress
                )
                
                Spacer()
                
                // Bottom controls
                HStack {
                    // Group ride toggle
                    if groupRideManager.isInGroupRide {
                        Button(action: { showingGroupPanel.toggle() }) {
                            HStack {
                                Image(systemName: "person.3.fill")
                                Text("\(groupRideManager.groupMembers.count)")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(25)
                            .shadow(radius: 4)
                        }
                    }
                    
                    Spacer()
                    
                    // Voice toggle
                    Button(action: { isVoiceEnabled.toggle() }) {
                        Image(systemName: isVoiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .padding()
                            .background(Color.gray.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(25)
                            .shadow(radius: 4)
                    }
                    
                    // Map style toggle
                    Button(action: toggleMapStyle) {
                        Image(systemName: "map.fill")
                            .padding()
                            .background(Color.gray.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(25)
                            .shadow(radius: 4)
                    }
                    
                    // End navigation
                    Button(action: endNavigation) {
                        Image(systemName: "xmark")
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(25)
                            .shadow(radius: 4)
                    }
                }
                .padding()
            }
            
            // Group panel overlay
            if showingGroupPanel {
                GroupRidePanel(
                    isShowing: $showingGroupPanel,
                    groupManager: groupRideManager
                )
                .transition(.move(edge: .trailing))
            }
        }
        .navigationBarHidden(true)
        .onReceive(locationManager.$location) { location in
            if let location = location {
                updateLocationTracking(location)
            }
        }
        .onReceive(groupRideManager.$groupMembers) { _ in
            // Update map when group members change
            updateCameraPosition()
        }
    }
    
    private func updateCameraPosition() {
        guard let userLocation = locationManager.location else { return }
        
        var region: MKCoordinateRegion
        
        if groupRideManager.isInGroupRide && !groupRideManager.groupMembers.isEmpty {
            // Include all group members in view
            let memberLocations: [CLLocationCoordinate2D] = groupRideManager.groupMembers.compactMap { member in
                guard let location = member.lastLocation else { return nil }
                return CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
            }
            let allLocations = memberLocations + [userLocation.coordinate]
            let minLat = allLocations.map { $0.latitude }.min() ?? userLocation.coordinate.latitude
            let maxLat = allLocations.map { $0.latitude }.max() ?? userLocation.coordinate.latitude
            let minLon = allLocations.map { $0.longitude }.min() ?? userLocation.coordinate.longitude
            let maxLon = allLocations.map { $0.longitude }.max() ?? userLocation.coordinate.longitude
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            let span = MKCoordinateSpan(
                latitudeDelta: max(maxLat - minLat, 0.01) * 1.2,
                longitudeDelta: max(maxLon - minLon, 0.01) * 1.2
            )
            region = MKCoordinateRegion(center: center, span: span)
        } else {
            // Focus on user and route
            region = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        cameraPosition = .region(region)
    }
    
    private func startNavigation() {
        locationManager.calculateRoute(to: destination)
        currentInstruction = "Calculating route to \(destinationName)..."
        
        // Join group ride if invited
        if groupRideManager.hasActiveInvite {
            // Note: In a real implementation, we'd need to get the actual ride ID from the invite
            // For now, this is a placeholder that would need the actual ride ID
            // groupRideManager.joinGroupRide(rideId) { result in ... }
        }
    }
    
    private func updateLocationTracking(_ location: CLLocation) {
        // Update current location for UI
        
        // Calculate ETA and distance
        if let route = locationManager.currentRoute {
            let remainingDistance = route.distance - location.distance(from: CLLocation(latitude: route.polyline.coordinate.latitude, longitude: route.polyline.coordinate.longitude))
            distanceToNextTurn = "\(String(format: "%.1f", remainingDistance / 1609.34)) mi" // Convert to miles
            
            let remainingTime = route.expectedTravelTime * (remainingDistance / route.distance)
            let eta = Date().addingTimeInterval(remainingTime)
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            estimatedArrival = "ETA: \(formatter.string(from: eta))"
            
            // Generate turn-by-turn instructions (simplified)
            generateTurnInstructions(for: location, route: route)
            
            // Share location with group if in group ride
            if groupRideManager.isInGroupRide {
                groupRideManager.updateLocation(location)
            }
        }
    }
    
    private func generateTurnInstructions(for location: CLLocation, route: MKRoute) {
        // Simplified turn instruction generation
        // In a real implementation, this would analyze the route steps and current position
        
        let distanceToDestination = location.distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
        
        if distanceToDestination < 100 {
            currentInstruction = "Arriving at destination"
            distanceToNextTurn = "Arrival"
            
            if isVoiceEnabled {
                speak("Arriving at destination")
            }
        } else if distanceToDestination < 500 {
            currentInstruction = "Continue straight"
            distanceToNextTurn = "\(Int(distanceToDestination))m"
        } else {
            currentInstruction = "Continue on current road"
            distanceToNextTurn = String(format: "%.1f km", distanceToDestination / 1000)
        }
    }
    
    private func speak(_ text: String) {
        guard isVoiceEnabled else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.volume = 0.8
        speechSynthesizer.speak(utterance)
    }
    
    private func toggleMapStyle() {
        mapStyleIndex = (mapStyleIndex + 1) % 3
        switch mapStyleIndex {
        case 0:
            selectedMapStyle = .standard(elevation: .realistic)
        case 1:
            selectedMapStyle = .hybrid(elevation: .realistic)
        case 2:
            selectedMapStyle = .imagery(elevation: .realistic)
        default:
            selectedMapStyle = .standard(elevation: .realistic)
        }
    }
    
    private func endNavigation() {
        locationManager.clearDestination()
        groupRideManager.leaveGroupRide { result in
            // Handle result if needed
        }
        dismiss()
    }
}

// MARK: - Supporting Views

struct NavigationInstructionPanel: View {
    let instruction: String
    let distanceToTurn: String
    let estimatedArrival: String
    let routeProgress: Double
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            ProgressView(value: routeProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(instruction)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(distanceToTurn)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(estimatedArrival)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white.opacity(0.95))
        .cornerRadius(12)
        .shadow(radius: 4)
        .padding(.horizontal)
    }
}

struct GroupMemberAnnotation: View {
    let member: GroupMember
    
    private var memberName: String {
        if let firstName = member.firstName, !firstName.isEmpty {
            return firstName
        }
        return member.username
    }
    
    private var memberInitial: String {
        String(memberName.prefix(1)).uppercased()
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(member.isOnline ? .green : .gray)
                .frame(width: 30, height: 30)
            
            Circle()
                .stroke(.white, lineWidth: 3)
                .frame(width: 30, height: 30)
            
            Text(memberInitial)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Show direction indicator if member is moving
            if let memberLocation = member.lastLocation,
               let heading = memberLocation.heading,
               let speed = memberLocation.speed,
               speed > 1 { // Only show direction if moving > 1 m/s
                
                Image(systemName: "location.north.fill")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(heading))
                    .offset(y: -15)
            }
        }
        .shadow(radius: 2)
    }
}

struct EnhancedGroupMemberAnnotation: View {
    let member: GroupMember
    
    private var memberName: String {
        if let firstName = member.firstName, !firstName.isEmpty {
            return firstName
        }
        return member.username
    }
    
    private var memberInitial: String {
        String(memberName.prefix(1)).uppercased()
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(member.isOnline ? .green : .gray)
                .frame(width: 30, height: 30)
            
            Circle()
                .stroke(.white, lineWidth: 3)
                .frame(width: 30, height: 30)
            
            Text(memberInitial)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Show direction indicator if member is moving
            if let memberLocation = member.lastLocation,
               let heading = memberLocation.heading,
               let speed = memberLocation.speed,
               speed > 1 { // Only show direction if moving > 1 m/s
                
                Image(systemName: "location.north.fill")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(heading))
                    .offset(y: -15)
            }
        }
        .shadow(radius: 2)
    }
}

struct SharedWaypointAnnotation: View {
    let waypoint: RouteWaypoint
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.orange)
                .frame(width: 25, height: 25)
            
            Circle()
                .stroke(.white, lineWidth: 2)
                .frame(width: 25, height: 25)
            
            Text("\(waypoint.order + 1)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .shadow(radius: 2)
    }
}

struct WaypointAnnotation: View {
    let waypoint: RouteWaypoint
    let index: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.orange)
                .frame(width: 25, height: 25)
            
            Circle()
                .stroke(.white, lineWidth: 2)
                .frame(width: 25, height: 25)
            
            Text("\(index + 1)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .shadow(radius: 2)
    }
}

struct GroupRidePanel: View {
    @Binding var isShowing: Bool
    @ObservedObject var groupManager: GroupRideManager
    
    var body: some View {
        HStack {
            Spacer()
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Group Ride")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: { isShowing = false }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                }
                
                ForEach(groupManager.groupMembers, id: \.id) { member in
                    GroupMemberRow(member: member)
                }
                
                Spacer()
                
                Button("Leave Group") {
                    groupManager.leaveGroupRide { result in
                        // Handle result if needed
                    }
                    isShowing = false
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                
                // Shared Route Section
                if let sharedRoute = groupManager.sharedRoute {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "map.fill")
                                .foregroundColor(.blue)
                            Text("Shared Route")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        Text(sharedRoute.name)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        if let distance = sharedRoute.totalDistance {
                            Text("Distance: \(String(format: "%.1f", distance / 1609.34)) miles")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Use This Route") {
                            groupManager.acceptSharedRoute { result in
                                switch result {
                                case .success:
                                    isShowing = false
                                case .failure(let error):
                                    print("Failed to accept route: \(error)")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            .frame(width: 250)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 8)
        }
        .padding()
    }
}

struct GroupMemberRow: View {
    let member: GroupMember
    
    private var memberDisplayName: String {
        let fullName = [member.firstName, member.lastName]
            .compactMap { $0 }
            .joined(separator: " ")
        return fullName.isEmpty ? member.username : fullName
    }
    
    private var memberSpeed: Double? {
        member.lastLocation?.speed
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(member.isOnline ? .green : .gray)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(memberDisplayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let speed = memberSpeed, speed > 0 {
                    Text("\(Int(speed * 2.237)) mph") // Convert m/s to mph
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Stopped")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let distance = member.distanceFromLeader {
                Text(formatDistance(distance))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
}

#Preview {
    RideNavigationView(
        destination: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4294),
        destinationName: "Golden Gate Bridge"
    )
    .environmentObject(LocationManager.shared)
    .environmentObject(GroupRideManager.shared)
} 


