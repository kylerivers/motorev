import SwiftUI
import MapKit
import Combine

struct RideEventsView: View {
    @EnvironmentObject var networkManager: NetworkManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var socialManager: SocialManager
    @State private var events: [RideEvent] = []
    @State private var completedRides: [CompletedRideData] = []
    @State private var isLoading = true
    @State private var isLoadingRides = false
    @State private var errorMessage: String?
    @State private var showingCreateEvent = false
    @State private var selectedEvent: RideEvent?
    @State private var selectedRide: CompletedRideData?
    @State private var searchText = ""
    @State private var selectedFilter: EventFilter = .all
    @State private var selectedTab: EventsTab = .events
    @State private var selectedRouteTab: RouteTab = .search
    @State private var cancellables = Set<AnyCancellable>()
    @State private var isShowingSampleData = false
    
    enum EventsTab: String, CaseIterable {
        case events = "Events"
        case rides = "Rides"
    }
    
    enum RouteTab: String, CaseIterable {
        case search = "Search"
        case planner = "Planner"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selection
                Picker("", selection: $selectedTab) {
                    ForEach(EventsTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Sample data banner
                if isShowingSampleData && selectedTab == .events {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text("Events API temporarily unavailable. Showing sample data.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                }
                
                // Tab content
                TabView(selection: $selectedTab) {
                    eventsTabContent
                        .tag(EventsTab.events)
                    
                    ridesTabContent
                        .tag(EventsTab.rides)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                

            }
            .navigationTitle("Ride Hub")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { 
                        if selectedTab == .events {
                            showingCreateEvent = true
                        }
                    }) {
                        Image(systemName: selectedTab == .events ? "plus" : "location.magnifyingglass")
                    }
                }
            }
        }
        .onAppear {
            loadEvents()
        }
        .sheet(isPresented: $showingCreateEvent) {
            CreateEventView {
                loadEvents()
            }
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event) {
                loadEvents()
            }
        }
    }
    
    // MARK: - Tab Content Views
    
    private var eventsTabContent: some View {
        VStack {
            // Search and filter bar
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search events...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Picker("Filter", selection: $selectedFilter) {
                    Text("All").tag(EventFilter.all)
                    Text("Nearby").tag(EventFilter.nearby)
                    Text("My Events").tag(EventFilter.myEvents)
                    Text("Joined").tag(EventFilter.joined)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding(.horizontal)
            
            // Events list
            Group {
                if isLoading {
                    ProgressView("Loading events...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            loadEvents()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredEvents.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No Events Found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Create a new event or adjust your search filters")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredEvents) { event in
                        EventRowView(event: event) {
                            selectedEvent = event
                        }
                    }
                    .refreshable {
                        loadEvents()
                    }
                }
            }
        }
    }
    
    private var ridesTabContent: some View {
        VStack {
            if isLoadingRides {
                ProgressView("Loading rides...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if completedRides.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "figure.motorcycle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No Completed Rides")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Start your first ride to see it here!")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Add Test Ride Data") {
                        addTestRideData()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(completedRides.sorted { $0.startTime > $1.startTime }) { ride in
                        RideHistoryCard(ride: ride)
                            .onTapGesture {
                                selectedRide = ride
                            }
                    }
                }
                .refreshable {
                    loadCompletedRides()
                }
            }
        }
        .onAppear {
            print("🔄 RideEventsView Rides tab appeared")
            print("📊 Current completed rides count: \(completedRides.count)")
            loadCompletedRides()
        }
        .sheet(item: $selectedRide) { ride in
            CompletedRideDetailView(ride: ride)
        }
    }
    
    private var routesTabContent: some View {
        VStack(spacing: 0) {
            // Sub-tabs for Routes
            Picker("Route Type", selection: $selectedRouteTab) {
                Text("Search").tag(RouteTab.search)
                Text("Planner").tag(RouteTab.planner)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.bottom)
            
            // Route content based on selected sub-tab
            if selectedRouteTab == .search {
                DestinationSearchContentView()
                    .environmentObject(locationManager)
            } else {
                PlanRideContentView()
                    .environmentObject(locationManager)
            }
        }
    }
    
    private var filteredEvents: [RideEvent] {
        var filtered = events
        
        // Apply text search
        if !searchText.isEmpty {
            filtered = filtered.filter { event in
                event.title.localizedCaseInsensitiveContains(searchText) ||
                event.description?.localizedCaseInsensitiveContains(searchText) == true ||
                event.location.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .nearby:
            // Filter by distance (placeholder implementation)
            break
        case .myEvents:
            filtered = filtered.filter { $0.isOrganizer }
        case .joined:
            filtered = filtered.filter { $0.isParticipating && !$0.isOrganizer }
        }
        
        return filtered.sorted { $0.startTime < $1.startTime }
    }
    
    private func loadEvents() {
        isLoading = true
        errorMessage = nil
        
        // Check if user is authenticated first
        guard networkManager.isLoggedIn && networkManager.authToken != nil else {
            self.errorMessage = "Please sign in to view events."
            self.isLoading = false
            print("🔑 User not authenticated, cannot load events")
            return
        }
        
        // Use NetworkManager to fetch events from backend
        networkManager.getEvents()
            .sink(receiveCompletion: { completion in
                DispatchQueue.main.async {
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        let message = error.localizedDescription
                        if message.contains("HTTP 404") || message.contains("Route not found") {
                            // Show sample events data when API is unavailable
                            self.events = self.createSampleEvents()
                            self.isShowingSampleData = true
                            self.errorMessage = nil
                            print("🔶 Events API unavailable, showing sample data")
                        } else if message.contains("No authentication token") || message.contains("Access token required") || message.contains("unauthorized") {
                            self.errorMessage = "Please sign in to view events."
                            print("🔑 Authentication required for events API")
                        } else if message.contains("The Internet connection appears to be offline") || message.contains("network connection lost") {
                            self.errorMessage = "Please check your internet connection."
                            print("🌐 Network connectivity issue")
                        } else {
                            self.errorMessage = "Failed to load events. Please try again."
                            print("🔴 Events loading error: \(error)")
                        }
                        self.isLoading = false
                    }
                }
            }, receiveValue: { response in
                DispatchQueue.main.async {
                    let dateFormatter = ISO8601DateFormatter()
                    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    
                    self.events = response.events.map { eventData in
                        RideEvent(
                            id: String(eventData.id),
                            title: eventData.title,
                            description: eventData.description,
                            startTime: dateFormatter.date(from: eventData.start_time) ?? Date(),
                            endTime: eventData.end_time != nil ? dateFormatter.date(from: eventData.end_time!) : nil,
                            location: eventData.location,
                            organizerUsername: eventData.organizer_username,
                            participantCount: eventData.participant_count,
                            maxParticipants: eventData.max_participants,
                            isPublic: eventData.is_public,
                            isOrganizer: eventData.organizer_username == self.socialManager.currentUser?.username,
                            isParticipating: eventData.is_participating == 1
                        )
                    }
                    self.isShowingSampleData = false
                    self.isLoading = false
                }
            })
            .store(in: &cancellables)
    }
    
    private func createSampleEvents() -> [RideEvent] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            RideEvent(
                id: "sample-1",
                title: "Weekend Mountain Ride",
                description: "Join us for a scenic ride through the mountains. Perfect for intermediate riders!",
                startTime: calendar.date(byAdding: .day, value: 1, to: now) ?? now,
                endTime: calendar.date(byAdding: .day, value: 1, to: now)?.addingTimeInterval(3600 * 4) ?? now,
                location: "Blue Ridge Parkway, NC",
                organizerUsername: "RiderPro",
                participantCount: 8,
                maxParticipants: 15,
                isPublic: true,
                isOrganizer: false,
                isParticipating: false
            ),
            RideEvent(
                id: "sample-2",
                title: "City Evening Cruise",
                description: "Relaxed evening ride through downtown. Great for beginners and social riders.",
                startTime: calendar.date(byAdding: .day, value: 3, to: now) ?? now,
                endTime: calendar.date(byAdding: .day, value: 3, to: now)?.addingTimeInterval(3600 * 2) ?? now,
                location: "Downtown Metro Area",
                organizerUsername: "CityRider",
                participantCount: 12,
                maxParticipants: 20,
                isPublic: true,
                isOrganizer: false,
                isParticipating: true
            ),
            RideEvent(
                id: "sample-3",
                title: "Track Day Experience",
                description: "Professional track day for experienced riders. Safety gear required.",
                startTime: calendar.date(byAdding: .day, value: 7, to: now) ?? now,
                endTime: calendar.date(byAdding: .day, value: 7, to: now)?.addingTimeInterval(3600 * 8) ?? now,
                location: "Motorsports Complex",
                organizerUsername: "TrackMaster",
                participantCount: 5,
                maxParticipants: 10,
                isPublic: true,
                isOrganizer: false,
                isParticipating: false
            )
        ]
    }
    
    private func loadCompletedRides() {
        isLoadingRides = true
        print("🔄 Loading completed rides from API...")
        
        networkManager.getCompletedRides()
            .sink(receiveCompletion: { completion in
                DispatchQueue.main.async {
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        print("❌ Failed to load completed rides: \(error)")
                        print("❌ Error details: \(error.localizedDescription)")
                        self.isLoadingRides = false
                    }
                }
            }, receiveValue: { response in
                DispatchQueue.main.async {
                    print("✅ Successfully loaded \(response.rides.count) completed rides")
                    self.completedRides = response.rides
                    self.isLoadingRides = false
                }
            })
            .store(in: &cancellables)
    }
    
    private func addTestRideData() {
        print("🔄 Adding test ride data...")
        
        networkManager.addTestRideData()
            .sink(receiveCompletion: { completion in
                DispatchQueue.main.async {
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        print("❌ Failed to add test ride data: \(error)")
                    }
                }
            }, receiveValue: { response in
                DispatchQueue.main.async {
                    print("✅ Successfully added test ride data: \(response.message)")
                    // Reload rides after adding test data
                    self.loadCompletedRides()
                }
            })
            .store(in: &cancellables)
    }
}

enum EventFilter: CaseIterable {
    case all, nearby, myEvents, joined
}

struct EventRowView: View {
    let event: RideEvent
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("by \(event.organizerUsername)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if event.isOrganizer {
                            Text("Hosting")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        } else if event.isParticipating {
                            Text("Joined")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Text("\(event.participantCount)/\(event.maxParticipants ?? 999)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                    Text(event.startTime, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(event.startTime, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: "location")
                        .foregroundColor(.secondary)
                    Text(event.location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let description = event.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EventDetailView: View {
    let event: RideEvent
    let onUpdate: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var networkManager: NetworkManager
    @State private var showingEditEvent = false
    @State private var isJoining = false
    @State private var isLeaving = false
    @State private var actionError: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title and organizer
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Organized by \(event.organizerUsername)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Date and time
                    VStack(alignment: .leading, spacing: 8) {
                        Label("When", systemImage: "calendar")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.startTime, style: .date)
                                .font(.body)
                            Text(event.startTime, style: .time)
                                .font(.body)
                            if let endTime = event.endTime {
                                Text("Until \(endTime, style: .time)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.leading)
                    }
                    
                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Location", systemImage: "location")
                            .font(.headline)
                        
                        Text(event.location)
                            .font(.body)
                            .padding(.leading)
                    }
                    
                    // Description
                    if let description = event.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Description", systemImage: "text.alignleft")
                                .font(.headline)
                            
                            Text(description)
                                .font(.body)
                                .padding(.leading)
                        }
                    }
                    
                    // Participants
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Participants", systemImage: "person.3")
                            .font(.headline)
                        
                        HStack {
                            Text("\(event.participantCount) joined")
                                .font(.body)
                            if let maxParticipants = event.maxParticipants {
                                Text("/ \(maxParticipants) max")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.leading)
                    }
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        if event.isOrganizer {
                            Button("Edit Event") {
                                showingEditEvent = true
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        } else if event.isParticipating {
                            Button(action: { leaveEvent() }) {
                                HStack {
                                    if isLeaving {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                    Text("Leave Event")
                                }
                            }
                            .disabled(isLeaving)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        } else {
                            Button(action: { joinEvent() }) {
                                HStack {
                                    if isJoining {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                    Text("Join Event")
                                }
                            }
                            .disabled(isJoining)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        if let actionError {
                            Text(actionError)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingEditEvent) {
            EditEventView(event: event) {
                onUpdate()
            }
        }
    }
    
    private func joinEvent() {
        isJoining = true
        actionError = nil
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Mock success
            self.isJoining = false
            self.onUpdate()
            self.dismiss()
        }
    }
    
    private func leaveEvent() {
        isLeaving = true
        actionError = nil
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Mock success
            self.isLeaving = false
            self.onUpdate()
            self.dismiss()
        }
    }
}

struct CreateEventView: View {
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var networkManager: NetworkManager
    
    @State private var title = ""
    @State private var description = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(7200) // 2 hours later
    @State private var location = ""
    @State private var maxParticipants: Int? = nil
    @State private var isPublic = true
    @State private var isCreating = false
    @State private var createError: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Details")) {
                    TextField("Event Title", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3)
                }
                
                Section(header: Text("Date & Time")) {
                    DatePicker("Start", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End (optional)", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text("Location")) {
                    TextField("Meeting point or route", text: $location)
                }
                
                Section(header: Text("Settings")) {
                    HStack {
                        Text("Max Participants")
                        Spacer()
                        TextField("Unlimited", value: $maxParticipants, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    Toggle("Public Event", isOn: $isPublic)
                }
                
                if let createError {
                    Section {
                        Text(createError)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createEvent()
                    }
                    .disabled(title.isEmpty || location.isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createEvent() {
        isCreating = true
        createError = nil
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Mock success
            self.isCreating = false
            self.onComplete()
            self.dismiss()
        }
    }
}

struct EditEventView: View {
    let event: RideEvent
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Edit Event")
                    .font(.headline)
                Text("Coming soon: Edit event functionality")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Route and Planner Content Views

struct DestinationSearchContentView: View {
    @EnvironmentObject var locationManager: LocationManager
    @State private var searchText = ""
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var isSearching = false
    @State private var recentSearches: [String] = []
    
    private let popularDestinations = [
        "Gas Station", "Restaurant", "Hotel", "Hospital", "Rest Area"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search destinations...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            search()
                        }
                    
                    if !searchText.isEmpty {
                        Button("Clear") {
                            searchText = ""
                            searchResults = []
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                if isSearching {
                    ProgressView("Searching...")
                        .font(.caption)
                }
            }
            .padding()
            
            // Results or suggestions
            if searchResults.isEmpty && searchText.isEmpty {
                // Show popular destinations and recent searches
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
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
            } else {
                // Show search results
                List(searchResults.indices, id: \.self) { index in
                    let result = searchResults[index]
                    Button(action: {
                        selectDestination(result)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .font(.headline)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }
    
    private func search() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        
        // Simulate search results
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let mockResults = [
                MockSearchResult(title: searchText, subtitle: "Nearby location"),
                MockSearchResult(title: "\(searchText) Station", subtitle: "0.5 miles away"),
                MockSearchResult(title: "\(searchText) Center", subtitle: "1.2 miles away")
            ]
            
            self.searchResults = mockResults.map { result in
                MockLocalSearchCompletion(title: result.title, subtitle: result.subtitle)
            }
            
            // Add to recent searches
            if !recentSearches.contains(searchText) {
                recentSearches.insert(searchText, at: 0)
                if recentSearches.count > 10 {
                    recentSearches.removeLast()
                }
            }
            
            self.isSearching = false
        }
    }
    
    private func selectDestination(_ result: MKLocalSearchCompletion) {
        // Set as destination in location manager
        print("Selected destination: \(result.title)")
        
        // Add to recent searches
        let searchTerm = result.title
        if !recentSearches.contains(searchTerm) {
            recentSearches.insert(searchTerm, at: 0)
            if recentSearches.count > 10 {
                recentSearches.removeLast()
            }
        }
    }
    
    private func iconForDestination(_ destination: String) -> String {
        switch destination.lowercased() {
        case "gas station": return "fuelpump.fill"
        case "restaurant": return "fork.knife"
        case "hotel": return "bed.double.fill"
        case "hospital": return "cross.fill"
        case "rest area": return "parkingsign"
        default: return "location.fill"
        }
    }
}

struct PlanRideContentView: View {
    @EnvironmentObject var locationManager: LocationManager
    @State private var startLocation = ""
    @State private var endLocation = ""
    @State private var stopLocation = ""
    @State private var selectedRouteType: RouteType = .fastest
    @State private var avoidTolls = false
    @State private var avoidHighways = false
    @State private var plannedDate = Date()
    @State private var estimatedDuration = "Unknown"
    @State private var estimatedDistance = "Unknown"
    
    enum RouteType: String, CaseIterable {
        case fastest = "Fastest"
        case scenic = "Scenic"
        case shortest = "Shortest"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Plan Your Route")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    // Start location
                    VStack(alignment: .leading, spacing: 4) {
                        Text("From")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            Image(systemName: "location.circle.fill")
                                .foregroundColor(.green)
                            TextField("Current location", text: $startLocation)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    // End location
                    VStack(alignment: .leading, spacing: 4) {
                        Text("To")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                            TextField("Enter destination", text: $endLocation)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    // Optional stop
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stop (Optional)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            Image(systemName: "mappin.circle")
                                .foregroundColor(.orange)
                            TextField("Add a stop", text: $stopLocation)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Route options
                VStack(alignment: .leading, spacing: 12) {
                    Text("Route Preferences")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Picker("Route Type", selection: $selectedRouteType) {
                        ForEach(RouteType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Avoid Tolls", isOn: $avoidTolls)
                        Toggle("Avoid Highways", isOn: $avoidHighways)
                    }
                    
                    DatePicker("Planned Departure", selection: $plannedDate, displayedComponents: [.date, .hourAndMinute])
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Route summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Route Summary")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Estimated Time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(estimatedDuration)
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Distance")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(estimatedDistance)
                                .font(.headline)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Action buttons
                VStack(spacing: 12) {
                    Button("Calculate Route") {
                        calculateRoute()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    
                    Button("Start Navigation") {
                        startNavigation()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(endLocation.isEmpty)
                }
            }
            .padding()
        }
    }
    
    private func calculateRoute() {
        // Simulate route calculation
        estimatedDuration = "1h 23m"
        estimatedDistance = "45.2 mi"
    }
    
    private func startNavigation() {
        // Start navigation with planned route
        print("Starting navigation to: \(endLocation)")
    }
}

// MARK: - Mock Data Models

struct MockSearchResult {
    let title: String
    let subtitle: String
}

class MockLocalSearchCompletion: MKLocalSearchCompletion {
    private let _title: String
    private let _subtitle: String
    
    init(title: String, subtitle: String) {
        self._title = title
        self._subtitle = subtitle
        super.init()
    }
    
    override var title: String { _title }
    override var subtitle: String { _subtitle }
}

// MARK: - Data Models

struct RideEvent: Identifiable {
    let id: String
    let title: String
    let description: String?
    let startTime: Date
    let endTime: Date?
    let location: String
    let organizerUsername: String
    let participantCount: Int
    let maxParticipants: Int?
    let isPublic: Bool
    let isOrganizer: Bool
    let isParticipating: Bool
}



// MARK: - Rides Data Models and Views

struct RideHistoryCard: View {
    let ride: CompletedRideData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack {
                    Image(systemName: ride.rideType.icon)
                        .foregroundColor(ride.rideType.color)
                    Text(ride.rideType.rawValue + " Ride")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ride.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(safetyScoreColor(ride.safetyScore))
                        Text("\(ride.safetyScore)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(safetyScoreColor(ride.safetyScore))
                    }
                }
            }
            
            // Stats
            HStack(spacing: 24) {
                RideStatItem(
                    icon: "road.lanes",
                    value: String(format: "%.1f mi", ride.distanceInMiles),
                    label: "Distance"
                )
                
                RideStatItem(
                    icon: "clock",
                    value: ride.formattedDuration,
                    label: "Duration"
                )
                
                RideStatItem(
                    icon: "speedometer",
                    value: String(format: "%.0f mph", ride.averageSpeed),
                    label: "Avg Speed"
                )
                
                if ride.maxSpeed > 0 {
                    RideStatItem(
                        icon: "gauge.high",
                        value: String(format: "%.0f mph", ride.maxSpeed),
                        label: "Max Speed"
                    )
                }
            }
            
            // Participants (if group ride)
            if ride.participants.count > 1 {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("\(ride.participants.count) riders")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func safetyScoreColor(_ score: Int) -> Color {
        switch score {
        case 90...100: return .green
        case 70...89: return .orange
        default: return .red
        }
    }
}

struct RideStatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CompletedRideDetailView: View {
    let ride: CompletedRideData
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: ride.rideType.icon)
                            .font(.system(size: 50))
                            .foregroundColor(ride.rideType.color)
                        
                        Text(ride.rideType.rawValue + " Ride")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(ride.formattedDate)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Detailed Stats
                    VStack(spacing: 16) {
                        HStack(spacing: 32) {
                            DetailStatCard(
                                title: "Distance",
                                value: String(format: "%.2f mi", ride.distanceInMiles),
                                icon: "road.lanes",
                                color: .blue
                            )
                            
                            DetailStatCard(
                                title: "Duration",
                                value: ride.formattedDuration,
                                icon: "clock",
                                color: .orange
                            )
                        }
                        
                        HStack(spacing: 32) {
                            DetailStatCard(
                                title: "Avg Speed",
                                value: String(format: "%.1f mph", ride.averageSpeed),
                                icon: "speedometer",
                                color: .green
                            )
                            
                            DetailStatCard(
                                title: "Max Speed",
                                value: String(format: "%.1f mph", ride.maxSpeed),
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
                            Text("\(ride.safetyScore)/100")
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
                    
                    // Route Map (placeholder)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Route")
                            .font(.headline)
                        
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(height: 200)
                            .overlay(
                                VStack {
                                    Image(systemName: "map")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("Route Map")
                                        .foregroundColor(.secondary)
                                }
                            )
                    }
                    
                    // Participants
                    if ride.participants.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Participants")
                                .font(.headline)
                            
                            ForEach(ride.participants) { participant in
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
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
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
    
    private var safetyScoreColor: Color {
        switch ride.safetyScore {
        case 90...100: return .green
        case 70...89: return .orange
        default: return .red
        }
    }
    
    private var safetyScoreText: String {
        switch ride.safetyScore {
        case 90...100: return "Excellent riding!"
        case 70...89: return "Good riding"
        default: return "Room for improvement"
        }
    }
}

struct DetailStatCard: View {
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

#Preview {
    RideEventsView()
        .environmentObject(NetworkManager.shared)
        .environmentObject(SocialManager.shared)
        .environmentObject(LocationManager.shared)
}
