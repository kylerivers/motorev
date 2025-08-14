import SwiftUI
import MapKit
import CoreLocation

struct FuelSessionView: View {
    @EnvironmentObject var locationManager: LocationManager
    @State private var fuelLogs: [FuelLogItem] = []
    @State private var showingAddLog = false
    @State private var isLoading = true
    @State private var locationName = "Current Location"
    
    // Fuel session settings
    @State private var showPremiumOnly = false
    @State private var showBikerFriendlyOnly = false
    @State private var showDieselOnly = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with location and settings
                headerSection
                
                // Fuel session settings (integrated cleanly)
                fuelSettingsSection
                
                // Main content
                ScrollView {
                    VStack(spacing: 16) {
                        // Quick stats section
                        fuelStatsSection
                        
                        // Fuel logs section
                        fuelLogsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Fuel Session")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddLog = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddLog) {
            AddFuelLogView()
        }
        .onAppear {
            loadFuelLogs()
            getLocationName()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.green)
                Text(locationName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button(action: refreshData) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
            }
            
            if let location = locationManager.location {
                Text("Lat: \(String(format: "%.4f", location.coordinate.latitude)), Lng: \(String(format: "%.4f", location.coordinate.longitude))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
    }
    
    private var fuelSettingsSection: some View {
        VStack(spacing: 12) {
            Text("Fuel Session Preferences")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                // Premium stations toggle
                Toggle(isOn: $showPremiumOnly) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Premium")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Text("Top-tier fuel")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .yellow))
                
                Spacer()
                
                // Biker friendly toggle
                Toggle(isOn: $showBikerFriendlyOnly) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: "bicycle")
                                .foregroundColor(.blue)
                            Text("Biker Friendly")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Text("Easy access")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            
            HStack(spacing: 20) {
                // Diesel toggle
                Toggle(isOn: $showDieselOnly) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: "truck.box.fill")
                                .foregroundColor(.orange)
                            Text("Diesel")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Text("Diesel fuel")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .orange))
                
                Spacer()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
    }
    
    private var fuelStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Overview")
                .font(.headline)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                // Total fuel this session
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Fuel")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", totalFuelThisSession)) gal")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Total cost this session
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Cost")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.2f", totalCostThisSession))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Number of fill-ups
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fill-ups")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(fuelLogs.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var fuelLogsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Fuel Logs")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button(action: {
                    showingAddLog = true
                }) {
                    Text("Add Entry")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            if fuelLogs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "fuelpump")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No Fuel Logs Yet")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("Tap the + button to add your first fuel entry")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        showingAddLog = true
                    }) {
                        Text("Add First Entry")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(20)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(fuelLogs.sorted(by: { $0.timestamp > $1.timestamp })) { log in
                        FuelLogRow(log: log)
                    }
                }
            }
        }
    }
    
    private var totalFuelThisSession: Double {
        fuelLogs.reduce(0) { $0 + $1.gallons }
    }
    
    private var totalCostThisSession: Double {
        fuelLogs.reduce(0) { $0 + $1.totalCost }
    }
    
    private func loadFuelLogs() {
        // Load from UserDefaults for now (replace with backend later)
        if let data = UserDefaults.standard.data(forKey: "fuelLogs"),
           let logs = try? JSONDecoder().decode([FuelLogItem].self, from: data) {
            self.fuelLogs = logs
        }
        isLoading = false
    }
    
    private func refreshData() {
        loadFuelLogs()
        getLocationName()
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func getLocationName() {
        guard let location = locationManager.location else { return }
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    if let city = placemark.locality, let state = placemark.administrativeArea {
                        self.locationName = "\(city), \(state)"
                    } else if let name = placemark.name {
                        self.locationName = name
                    }
                }
            }
        }
    }
}

struct FuelLogRow: View {
    let log: FuelLogItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Fuel type icon
            VStack {
                Image(systemName: fuelIcon)
                    .font(.title2)
                    .foregroundColor(fuelColor)
                Text(log.fuelType)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 50)
            
            // Main info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                                            Text(log.displayStationName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("$\(String(format: "%.2f", log.totalCost))")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("\(String(format: "%.2f", log.gallons)) gal")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.3f", log.pricePerGallon))/gal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(log.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var fuelIcon: String {
        switch log.fuelType.lowercased() {
        case "diesel":
            return "truck.box.fill"
        case "premium", "premium unleaded":
            return "star.fill"
        default:
            return "fuelpump.fill"
        }
    }
    
    private var fuelColor: Color {
        switch log.fuelType.lowercased() {
        case "diesel":
            return .orange
        case "premium", "premium unleaded":
            return .yellow
        default:
            return .blue
        }
    }
}

struct AddFuelLogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var stationName = ""
    @State private var fuelType = "Regular"
    @State private var gallons = ""
    @State private var pricePerGallon = ""
    @State private var notes = ""
    
    private let fuelTypes = ["Regular", "Premium", "Diesel"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Station Information") {
                    TextField("Station Name", text: $stationName)
                    Picker("Fuel Type", selection: $fuelType) {
                        ForEach(fuelTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }
                
                Section("Fuel Details") {
                    TextField("Gallons", text: $gallons)
                        .keyboardType(.decimalPad)
                    TextField("Price per Gallon", text: $pricePerGallon)
                        .keyboardType(.decimalPad)
                }
                
                Section("Notes (Optional)") {
                    TextField("Additional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Fuel Entry")
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
                    .disabled(!isFormValid)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !stationName.isEmpty && 
        !gallons.isEmpty && 
        !pricePerGallon.isEmpty &&
        Double(gallons) != nil &&
        Double(pricePerGallon) != nil
    }
    
    private func saveFuelLog() {
        guard let gallonsDouble = Double(gallons),
              let priceDouble = Double(pricePerGallon) else { return }
        
        let newLog = FuelLogItem.createLocal(
            stationName: stationName,
            fuelType: fuelType,
            gallons: gallonsDouble,
            pricePerGallon: priceDouble,
            notes: notes.isEmpty ? nil : notes
        )
        
        // Save to UserDefaults (replace with backend later)
        var existingLogs: [FuelLogItem] = []
        if let data = UserDefaults.standard.data(forKey: "fuelLogs"),
           let logs = try? JSONDecoder().decode([FuelLogItem].self, from: data) {
            existingLogs = logs
        }
        
        existingLogs.append(newLog)
        
        if let data = try? JSONEncoder().encode(existingLogs) {
            UserDefaults.standard.set(data, forKey: "fuelLogs")
        }
        
        dismiss()
    }
}

#Preview {
    FuelSessionView()
}
