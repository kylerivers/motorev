import SwiftUI
import MapKit

struct SearchPlacesView: View {
    @EnvironmentObject var networkManager: NetworkManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var searchText = ""
    @State private var searchResults: [SearchResult] = []
    @State private var places: [Place] = []
    @State private var selectedPlace: Place?
    @State private var showingSubmitPlace = false
    @State private var isLoading = false
    @State private var selectedTab: SearchTab = .search
    
    enum SearchTab: String, CaseIterable {
        case search = "Search"
        case places = "Places"
        case submit = "Submit"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selection
                Picker("", selection: $selectedTab) {
                    ForEach(SearchTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Tab content
                TabView(selection: $selectedTab) {
                    searchTabContent
                        .tag(SearchTab.search)
                    
                    placesTabContent
                        .tag(SearchTab.places)
                    
                    submitPlaceTabContent
                        .tag(SearchTab.submit)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Search & Places")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            loadPlaces()
        }
    }
    
    // MARK: - Tab Content Views
    
    private var searchTabContent: some View {
        VStack {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search places, businesses, events...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        performSearch()
                    }
                
                Button("Search") {
                    performSearch()
                }
                .disabled(searchText.isEmpty)
            }
            .padding()
            
            if isLoading {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No Results Found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Try searching for businesses, places, or events")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !searchResults.isEmpty {
                List(searchResults) { result in
                    SearchResultRowView(result: result) {
                        // Handle selection
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "location.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("Search for Places")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Find businesses, events, and motorcycle meetup spots")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private var placesTabContent: some View {
        VStack {
            if places.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No Places Yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Submit a place to get started!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(places) { place in
                    PlaceRowView(place: place) {
                        selectedPlace = place
                    }
                }
            }
        }
        .sheet(item: $selectedPlace) { place in
            PlaceDetailView(place: place)
        }
    }
    
    private var submitPlaceTabContent: some View {
        SubmitPlaceView()
            .environmentObject(networkManager)
            .environmentObject(locationManager)
    }
    
    // MARK: - Helper Methods
    
    private func performSearch() {
        isLoading = true
        // TODO: Implement search functionality
        // This should search both regular places/businesses AND user-submitted places
        // It should also show if any events are happening at these locations
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isLoading = false
            // Placeholder results
            self.searchResults = []
        }
    }
    
    private func loadPlaces() {
        // TODO: Load user-submitted and approved places from backend
        places = []
    }
}

// MARK: - Supporting Views

struct SearchResult: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let type: ResultType
    let hasEvents: Bool
    let upcomingEvents: [String]
    
    enum ResultType {
        case business
        case userPlace
        case landmark
    }
}

struct SearchResultRowView: View {
    let result: SearchResult
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading) {
                    Text(result.name)
                        .font(.headline)
                    Text(result.address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if result.hasEvents {
                    VStack {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .foregroundColor(.orange)
                        Text("Events")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            if !result.upcomingEvents.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Upcoming Events:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    ForEach(result.upcomingEvents, id: \.self) { event in
                        Text("• \(event)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .onTapGesture {
            onTap()
        }
    }
}

struct Place: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let address: String
    let latitude: Double
    let longitude: Double
    let submittedBy: String
    let isApproved: Bool
    let category: PlaceCategory
    let upcomingEvents: [String]
    
    enum PlaceCategory: String, CaseIterable {
        case meetupSpot = "Meetup Spot"
        case scenic = "Scenic Route"
        case restaurant = "Restaurant"
        case gas = "Gas Station"
        case garage = "Garage/Service"
        case other = "Other"
    }
}

struct PlaceRowView: View {
    let place: Place
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading) {
                    Text(place.name)
                        .font(.headline)
                    Text(place.category.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                if !place.upcomingEvents.isEmpty {
                    VStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(.green)
                        Text("\(place.upcomingEvents.count)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Text(place.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .onTapGesture {
            onTap()
        }
    }
}

struct PlaceDetailView: View {
    let place: Place
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Place details
                    VStack(alignment: .leading, spacing: 8) {
                        Text(place.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(place.category.rawValue)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                        
                        Text(place.description)
                            .font(.body)
                        
                        Text("Submitted by: @\(place.submittedBy)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Events section
                    if !place.upcomingEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Upcoming Events")
                                .font(.headline)
                            
                            ForEach(place.upcomingEvents, id: \.self) { event in
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.green)
                                    Text(event)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Place Details")
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

struct SubmitPlaceView: View {
    @EnvironmentObject var networkManager: NetworkManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var name = ""
    @State private var description = ""
    @State private var category: Place.PlaceCategory = .meetupSpot
    @State private var useCurrentLocation = true
    @State private var customAddress = ""
    @State private var isSubmitting = false
    @State private var showingSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Submit a New Place")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Help the community by submitting cool motorcycle spots, meetup locations, or scenic routes!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Place Name *")
                        .font(.headline)
                    TextField("Enter place name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("Description *")
                        .font(.headline)
                    TextField("Describe this place...", text: $description, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                    
                    Text("Category")
                        .font(.headline)
                    Picker("Category", selection: $category) {
                        ForEach(Place.PlaceCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Text("Location")
                        .font(.headline)
                    
                    Toggle("Use current location", isOn: $useCurrentLocation)
                    
                    if !useCurrentLocation {
                        TextField("Enter address", text: $customAddress)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                Button(action: submitPlace) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isSubmitting ? "Submitting..." : "Submit Place")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSubmit ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!canSubmit || isSubmitting)
                
                Text("Note: All submitted places are reviewed by admins before appearing on the map.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .alert("Success!", isPresented: $showingSuccess) {
            Button("OK") {
                // Clear form
                name = ""
                description = ""
                category = .meetupSpot
                customAddress = ""
            }
        } message: {
            Text("Your place has been submitted for review. It will appear on the map once approved by an admin.")
        }
    }
    
    private var canSubmit: Bool {
        !name.isEmpty && !description.isEmpty && (useCurrentLocation || !customAddress.isEmpty)
    }
    
    private func submitPlace() {
        isSubmitting = true
        
        // TODO: Implement place submission to backend
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isSubmitting = false
            self.showingSuccess = true
        }
    }
}

#Preview {
    SearchPlacesView()
        .environmentObject(NetworkManager.shared)
        .environmentObject(LocationManager.shared)
}
