import SwiftUI
import MapKit
import CoreLocation

struct SearchPlacesView: View {
    @EnvironmentObject var networkManager: NetworkManager
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var searchText = ""
    @State private var searchResults: [PlaceSearchResult] = []
    @State private var isLoading = false
    @State private var selectedTab = 0
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var showingSubmitPlace = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBarView
                
                // Tab Selector
                Picker("Search Type", selection: $selectedTab) {
                    Text("Places").tag(0)
                    Text("Events").tag(1)
                    Text("Routes").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    // Places Tab
                    placesSearchView
                        .tag(0)
                    
                    // Events Tab
                    eventsSearchView
                        .tag(1)
                    
                    // Routes Tab
                    routesSearchView
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Submit Place") {
                    showingSubmitPlace = true
                }
                .font(.subheadline)
            }
        }
        .sheet(isPresented: $showingSubmitPlace) {
            SubmitPlaceView()
                .environmentObject(networkManager)
                .environmentObject(locationManager)
        }
        .onAppear {
            if let userLocation = locationManager.location {
                region.center = userLocation.coordinate
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search places, events, or routes...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit {
                    performSearch()
                }
                .onChange(of: searchText) { _, newValue in
                    if newValue.isEmpty {
                        searchResults = []
                    }
                }
            
            if !searchText.isEmpty {
                Button("Clear") {
                    searchText = ""
                    searchResults = []
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
    }
    
    // MARK: - Places Search View
    private var placesSearchView: some View {
        VStack {
            if isLoading {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No places found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Try a different search term or submit this as a new place")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Submit '\(searchText)' as Place") {
                        showingSubmitPlace = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "location.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("Search for Places")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Find motorcycle meetup spots, scenic routes, gas stations, and more")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Search Results
                List(searchResults) { result in
                    PlaceResultRow(result: result)
                }
            }
        }
    }
    
    // MARK: - Events Search View
    private var eventsSearchView: some View {
        VStack {
            if searchText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("Search for Events")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Find motorcycle events, group rides, and meetups at specific places")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Events search results would go here
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Events Search Coming Soon")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Event search functionality will be available once the Places system is implemented")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Routes Search View
    private var routesSearchView: some View {
        VStack {
            if searchText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "map")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("Search for Routes")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Find scenic motorcycle routes, popular riding paths, and custom routes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Routes search results would go here
                VStack(spacing: 16) {
                    Image(systemName: "map.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Routes Search Coming Soon")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Route search functionality will be expanded in future updates")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Actions
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isLoading = true
        
        // Simulate search with MapKit for now
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let response = response {
                    self.searchResults = response.mapItems.map { item in
                        PlaceSearchResult(
                            id: UUID(),
                            name: item.name ?? "Unknown",
                            address: item.placemark.title ?? "",
                            coordinate: item.placemark.coordinate,
                            category: item.pointOfInterestCategory?.rawValue ?? "Place",
                            hasEvents: false, // Will be populated when Places system is implemented
                            eventCount: 0
                        )
                    }
                } else {
                    self.searchResults = []
                }
            }
        }
    }
}

// MARK: - Place Result Row
struct PlaceResultRow: View {
    let result: PlaceSearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(result.address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(result.category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                    
                    if result.hasEvents {
                        Text("\(result.eventCount) events")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("View Details") {
                    // Navigate to place details
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
                
                Button("Get Directions") {
                    openInMaps()
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
                
                if result.hasEvents {
                    Button("View Events") {
                        // Navigate to events at this place
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
    
    private func openInMaps() {
        let placemark = MKPlacemark(coordinate: result.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = result.name
        mapItem.openInMaps()
    }
}

// MARK: - Submit Place View
struct SubmitPlaceView: View {
    @EnvironmentObject var networkManager: NetworkManager
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var placeName = ""
    @State private var placeDescription = ""
    @State private var placeCategory = "Meetup Spot"
    @State private var useCurrentLocation = true
    @State private var customAddress = ""
    @State private var isSubmitting = false
    
    let categories = ["Meetup Spot", "Scenic Route", "Gas Station", "Restaurant", "Parking", "Viewpoint", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Place Information") {
                    TextField("Place Name", text: $placeName)
                    
                    TextField("Description (optional)", text: $placeDescription, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Picker("Category", selection: $placeCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }
                
                Section("Location") {
                    Toggle("Use Current Location", isOn: $useCurrentLocation)
                    
                    if !useCurrentLocation {
                        TextField("Address", text: $customAddress)
                    }
                }
                
                Section {
                    Button("Submit Place") {
                        submitPlace()
                    }
                    .disabled(placeName.isEmpty || isSubmitting)
                    
                    if isSubmitting {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Submitting...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Submit Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func submitPlace() {
        guard !placeName.isEmpty else { return }
        
        isSubmitting = true
        
        // TODO: Implement actual API call to submit place
        // For now, simulate submission
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isSubmitting = false
            self.dismiss()
        }
    }
}

// MARK: - Place Search Result Model
struct PlaceSearchResult: Identifiable {
    let id: UUID
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let category: String
    let hasEvents: Bool
    let eventCount: Int
}

#Preview {
    SearchPlacesView()
        .environmentObject(NetworkManager.shared)
        .environmentObject(LocationManager.shared)
}


