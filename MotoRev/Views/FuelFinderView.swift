import SwiftUI
import MapKit
import CoreLocation
import Combine

struct FuelFinderView: View {
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    @State private var fuelStations: [FuelStation] = []
    @State private var fuelLogs: [FuelLogItem] = []
    @State private var selectedStation: FuelStation?
    @State private var showingFuelLog = false
    @State private var isLoading = false
    @State private var searchRadius: Double = 10.0
    @State private var cancellables = Set<AnyCancellable>() // Added for Combine subscriptions
    @State private var showPremiumOnly = false
    @State private var showBikerFriendlyOnly = false
    @State private var showDieselOnly = false
    @State private var maxPriceRegular: Double = 0
    @State private var showingSettings = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            mainContent
        }
        .sheet(item: $selectedStation) { station in
            FuelStationDetailView(station: station) {
                showingFuelLog = true
            }
        }
        .sheet(isPresented: $showingFuelLog) {
            AddFuelLogView(station: selectedStation) { newLog in
                // Save to local storage
                addFuelLog(newLog)
                let request = CreateFuelLogRequest(
                    bikeId: BikeManager.shared.primaryBike?.id ?? 1,
                    date: ISO8601DateFormatter().string(from: Date()),
                    stationName: newLog.stationName,
                    fuelType: newLog.fuelType,
                    gallons: newLog.gallons,
                    pricePerGallon: newLog.pricePerGallon,
                    totalCost: newLog.totalCost,
                    odometer: newLog.odometer,
                    notes: newLog.notes
                )
                
                NetworkManager.shared.createFuelLog(request)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { _ in
                        // Optionally refresh list after successful save
                        NetworkManager.shared.listFuelLogs()
                            .map { $0.fuelLogs }
                            .receive(on: DispatchQueue.main)
                            .sink(receiveCompletion: { _ in }, receiveValue: { items in
                                // Use API items directly since they're already FuelLogItem
                                self.fuelLogs = items.sorted { $0.timestamp > $1.timestamp }
                            })
                            .store(in: &cancellables)
                    }, receiveValue: { _ in
                        // Successfully created fuel log
                    })
                    .store(in: &cancellables)
            }
        }
        .sheet(isPresented: $showingSettings) {
            FuelSettingsView(
                showPremiumOnly: $showPremiumOnly,
                showBikerFriendlyOnly: $showBikerFriendlyOnly,
                showDieselOnly: $showDieselOnly,
                maxPriceRegular: $maxPriceRegular
            )
        }
        .task {
            loadFuelLogs()
            
            // Auto-find fuel stations when view loads
            if locationManager.location != nil {
                findNearbyFuelStations()
            }
        }
        .onChange(of: locationManager.location) { oldLocation, newLocation in
            // Auto-search when location becomes available
            if oldLocation == nil && newLocation != nil {
                findNearbyFuelStations()
            }
        }
    }
    
    private var mainContent: some View {
        VStack {
                // Location Status
                if locationManager.location == nil {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "location.slash")
                                .foregroundColor(.orange)
                            Text("Location Required")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                        
                        Text("Please enable location services to find nearby fuel stations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Request Location") {
                            locationManager.requestLocationPermission()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                } else {
                    // Fuel Stations Content
                    if isLoading {
                        VStack {
                            ProgressView("Finding fuel stations...")
                            Text("Searching within \(searchRadius, specifier: "%.0f") miles")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if fuelStations.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "fuelpump.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No Fuel Stations Found")
                                .font(.headline)
                            
                            Text("Try increasing the search radius or check your location.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Search Again") {
                                findNearbyFuelStations()
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        TabView(selection: $selectedTab) {
                            // Map View
                            FuelStationMapView(
                                stations: filteredStations(),
                                selectedStation: $selectedStation
                            )
                            .tabItem {
                                Image(systemName: "map")
                                Text("Map")
                            }
                            .tag(0)
                            
                            // List View
                            List {
                                ForEach(filteredStations()) { station in
                                    Button {
                                        selectedStation = station
                                    } label: {
                                        FuelStationRow(station: station)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .tabItem {
                                Image(systemName: "list.bullet")
                                Text("List")
                            }
                            .tag(1)
                            
                            // Fuel Logs Tab
                            VStack {
                                if fuelLogs.isEmpty {
                                    VStack(spacing: 16) {
                                        Image(systemName: "fuelpump.slash")
                                            .font(.system(size: 48))
                                            .foregroundColor(.secondary)
                                        
                                        Text("No Fuel Logs")
                                            .font(.headline)
                                        
                                        Text("Start logging your fuel purchases to track your spending.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                        
                                        Button("Log Fuel") {
                                            showingFuelLog = true
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                } else {
                                    List {
                                        ForEach(fuelLogs, id: \.id) { log in
                                            FuelLogRow(log: log)
                                        }
                                    }
                                    
                                    // Quick Stats
                                    VStack(spacing: 8) {
                                        Text("Recent Stats")
                                            .font(.headline)
                                        
                                        HStack {
                                            VStack {
                                                Text("\(fuelLogs.count)")
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                                Text("Fill-ups")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            VStack {
                                                Text("$\(fuelLogs.reduce(0) { $0 + $1.totalCost }, specifier: "%.2f")")
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                                Text("Total Spent")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .padding(.horizontal)
                                        
                                        NavigationLink("View All Logs") {
                                            FuelLogHistoryView(logs: fuelLogs)
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            .tabItem {
                                Image(systemName: "list.clipboard")
                                Text("Logs")
                            }
                            .tag(2)
                        }
                    }
                }
            }
            .navigationTitle("Fuel Finder")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // X button always on top left
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("✕") {
                        dismiss()
                    }
                    .font(.title2)
                    .foregroundColor(.secondary)
                }
                
                // Log Fuel + Settings always on top right
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Log Fuel") {
                        showingFuelLog = true
                    }
                    .font(.subheadline)
                    
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .font(.subheadline)
                }
            }
    }
    
    // MARK: - Helper Methods
    
    private func findNearbyFuelStations() {
        guard let location = locationManager.location else { return }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "gas station"
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 10000,
            longitudinalMeters: 10000
        )
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let error = error {
                print("Search error: \(error)")
                return
            }
            
            guard let response = response else { return }
            
            let stations = response.mapItems.map { item in
                FuelStation(
                    id: UUID(),
                    name: item.name ?? "Unknown Station",
                    address: item.placemark.title ?? "",
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude,
                    distance: location.distance(from: CLLocation(
                        latitude: item.placemark.coordinate.latitude,
                        longitude: item.placemark.coordinate.longitude
                    )) / 1609.34, // Convert to miles
                    regularPrice: nil,
                    premiumPrice: nil,
                    dieselPrice: nil,
                    amenities: []
                )
            }
            
            DispatchQueue.main.async {
                self.fuelStations = stations
            }
        }
    }
    
    private func filteredStations() -> [FuelStation] {
        var stations = fuelStations
        
        if showPremiumOnly {
            stations = stations.filter { $0.premiumPrice != nil }
        }
        
        if showDieselOnly {
            stations = stations.filter { $0.dieselPrice != nil }
        }
        
        if maxPriceRegular > 0 {
            stations = stations.filter {
                guard let price = $0.regularPrice else { return false }
                return price <= maxPriceRegular
            }
        }
        
        return stations.sorted { $0.distance < $1.distance }
    }
    
    private func loadFuelLogs() {
        // Load from UserDefaults for persistence
        if let data = UserDefaults.standard.data(forKey: "FuelLogs"),
           let logs = try? JSONDecoder().decode([FuelLogItem].self, from: data) {
            fuelLogs = logs.sorted { $0.timestamp > $1.timestamp }
        } else {
            // If no saved logs, start with empty array
            fuelLogs = []
        }
    }
    
    private func saveFuelLogs() {
        if let data = try? JSONEncoder().encode(fuelLogs) {
            UserDefaults.standard.set(data, forKey: "FuelLogs")
        }
    }
    
    private func addFuelLog(_ log: FuelLogItem) {
        fuelLogs.insert(log, at: 0)
        saveFuelLogs()
    }
}

// MARK: - Data Models

struct FuelStation: Identifiable, Equatable {
    let id: UUID
    let name: String
    let brand: String
    let address: String
    let latitude: Double
    let longitude: Double
    let distance: Double
    let regularPrice: Double?
    let premiumPrice: Double?
    let dieselPrice: Double?
    let amenities: [String]
    
    init(id: UUID = UUID(), name: String, address: String, latitude: Double, longitude: Double, distance: Double, regularPrice: Double? = nil, premiumPrice: Double? = nil, dieselPrice: Double? = nil, amenities: [String] = []) {
        self.id = id
        self.name = name
        self.brand = "" // Default empty brand
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.distance = distance
        self.regularPrice = regularPrice
        self.premiumPrice = premiumPrice
        self.dieselPrice = dieselPrice
        self.amenities = amenities
    }
}

struct FuelStationMapView: View {
    let stations: [FuelStation]
    @Binding var selectedStation: FuelStation?
    
    var body: some View {
        Map {
            ForEach(stations) { station in
                Annotation(station.name, coordinate: CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude)) {
                    Button {
                        selectedStation = station
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "fuelpump.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            if let price = station.regularPrice {
                                Text("$\(price, specifier: "%.2f")")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .background(Color.blue.opacity(0.8))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
    }
}

struct FuelStationRow: View {
    let station: FuelStation
    
    var body: some View {
        HStack(spacing: 12) {
            // Station icon
            Image(systemName: "fuelpump.fill")
                .foregroundColor(.blue)
                .font(.title2)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(station.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(station.address)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text("\(station.distance, specifier: "%.1f") mi")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let price = station.regularPrice {
                        Text("$\(price, specifier: "%.2f")")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }
}

struct FuelLogRow: View {
    let log: FuelLogItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "fuelpump.circle.fill")
                .foregroundColor(.orange)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(log.displayStationName)
                    .font(.headline)
                
                HStack {
                    Text("\(log.gallons, specifier: "%.2f") gal")
                    Text("•")
                    Text("$\(log.pricePerGallon, specifier: "%.2f")/gal")
                    Spacer()
                    Text("$\(log.totalCost, specifier: "%.2f")")
                        .fontWeight(.semibold)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Text(log.timestamp, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct FuelStationDetailView: View {
    let station: FuelStation
    let onLogFuel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Station Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(station.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(station.address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(station.distance, specifier: "%.1f") miles away")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
                
                // Fuel Prices
                if station.regularPrice != nil || station.premiumPrice != nil || station.dieselPrice != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fuel Prices")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            if let regular = station.regularPrice {
                                PriceRow(type: "Regular", price: regular)
                            }
                            if let premium = station.premiumPrice {
                                PriceRow(type: "Premium", price: premium)
                            }
                            if let diesel = station.dieselPrice {
                                PriceRow(type: "Diesel", price: diesel)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // Log Fuel Button
                Button("Log Fuel Purchase") {
                    onLogFuel()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
        }
        .navigationTitle("Station Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PriceRow: View {
    let type: String
    let price: Double
    
    var body: some View {
        HStack {
            Text(type)
                .font(.subheadline)
            
            Spacer()
            
            Text("$\(price, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

struct AddFuelLogView: View {
    let station: FuelStation?
    let onSave: (FuelLogItem) -> Void
    
    @State private var selectedFuelType = "Regular"
    @State private var gallons = ""
    @State private var pricePerGallon = ""
    @State private var odometer = ""
    @State private var notes = ""
    
    @Environment(\.dismiss) private var dismiss
    
    private let fuelTypes = ["Regular", "Premium", "Diesel"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Station") {
                    Text(station?.name ?? "Manual Entry")
                        .foregroundColor(.secondary)
                }
                
                Section("Fuel Details") {
                    Picker("Fuel Type", selection: $selectedFuelType) {
                        ForEach(fuelTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    TextField("Gallons", text: $gallons)
                        .keyboardType(.decimalPad)
                    
                    TextField("Price per Gallon", text: $pricePerGallon)
                        .keyboardType(.decimalPad)
                    
                    TextField("Odometer (optional)", text: $odometer)
                        .keyboardType(.numberPad)
                }
                
                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("Log Fuel Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveFuelLog()
                    }
                    .disabled(!isValidInput)
                }
            }
        }
    }
    
    private var isValidInput: Bool {
        !gallons.isEmpty && !pricePerGallon.isEmpty
    }
    
    private func saveFuelLog() {
        guard let gallonsValue = Double(gallons),
              let priceValue = Double(pricePerGallon) else {
            return
        }
        
        let log = FuelLogItem.createLocal(
            stationName: station?.name ?? "Manual Entry",
            fuelType: selectedFuelType,
            gallons: gallonsValue,
            pricePerGallon: priceValue,
            notes: notes.isEmpty ? nil : notes
        )
        
        onSave(log)
        dismiss()
    }
}

struct FuelLogHistoryView: View {
    let logs: [FuelLogItem]
    
    private var totalSpent: Double {
        logs.reduce(0) { $0 + $1.totalCost }
    }
    
    private var totalGallons: Double {
        logs.reduce(0) { $0 + $1.gallons }
    }
    
    private var averagePrice: Double {
        guard !logs.isEmpty else { return 0 }
        return totalSpent / totalGallons
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if logs.isEmpty {
                    ContentUnavailableView {
                        Label("No Fuel Logs", systemImage: "fuelpump.slash")
                    } description: {
                        Text("Start logging your fuel purchases to see your history here.")
                    }
                } else {
                    // Summary Stats
                    VStack(spacing: 16) {
                        HStack(spacing: 20) {
                            FuelStatCard(title: "Total Spent", value: String(format: "$%.2f", totalSpent), color: .red)
                            FuelStatCard(title: "Total Gallons", value: String(format: "%.1f", totalGallons), color: .blue)
                            FuelStatCard(title: "Avg Price", value: String(format: "$%.2f", averagePrice), color: .green)
                        }
                        .padding(.horizontal)
                        
                        Divider()
                    }
                    
                    // Fuel Log List
                    List {
                        ForEach(logs, id: \.id) { log in
                            FuelLogRow(log: log)
                        }
                    }
                }
            }
            .navigationTitle("Fuel Log History")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct FuelStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct FuelSettingsView: View {
    @Binding var showPremiumOnly: Bool
    @Binding var showBikerFriendlyOnly: Bool
    @Binding var showDieselOnly: Bool
    @Binding var maxPriceRegular: Double
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Filter Options")) {
                    Toggle("Premium Only", isOn: $showPremiumOnly)
                    Toggle("Biker Friendly Only", isOn: $showBikerFriendlyOnly)
                    Toggle("Diesel Only", isOn: $showDieselOnly)
                }
                
                Section(header: Text("Price Filters")) {
                    HStack {
                        Text("Max Regular Price:")
                        Spacer()
                        TextField("$0.00", value: $maxPriceRegular, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    if maxPriceRegular > 0 {
                        Text("Only showing stations with regular gas at or below $\(maxPriceRegular, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Set to $0.00 to show all stations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("About")) {
                    Text("These settings help you filter fuel stations based on your preferences and budget.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Fuel Settings")
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