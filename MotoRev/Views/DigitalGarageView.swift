import SwiftUI
import Combine

struct DigitalGarageView: View {
    @EnvironmentObject var bikeManager: BikeManager
    @State private var showingAddBike = false
    @State private var selectedBike: Bike?
    @State private var showingBikeDetail = false
    @State private var showingMaintenanceView = false
    @State private var selectedBikeForMaintenance: Bike?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with total bikes and quick stats
                    headerSection
                    
                    // Primary bike highlight
                    if let primaryBike = bikeManager.primaryBike {
                        primaryBikeSection(primaryBike)
                    }
                    
                    // All bikes grid
                    bikesGridSection
                    
                    // Quick actions
                    quickActionsSection
                    NavigationLink("View Friend's Garage") {
                        ViewFriendsGarageView()
                    }
                }
                .padding()
            }
            .navigationTitle("🏍️ Digital Garage")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddBike = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .refreshable {
                bikeManager.loadBikes()
            }
            .sheet(isPresented: $showingAddBike) {
                AddEditBikeView()
            }
            .sheet(item: $selectedBike) { bike in
                BikeDetailView(bike: bike)
            }
            .sheet(item: $selectedBikeForMaintenance) { bike in
                MaintenanceView(bike: bike)
            }
            .onAppear {
                if bikeManager.bikes.isEmpty {
                    bikeManager.loadBikes()
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("\(bikeManager.bikes.count)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Bikes in Garage")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(totalMileage)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Text("Total Miles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(adaptiveCardBackground)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Primary Bike Section
    private func primaryBikeSection(_ bike: Bike) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Primary Bike")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
            }
            
            BikeCardView(bike: bike, isPrimary: true) {
                selectedBike = bike
                showingBikeDetail = true
            }
        }
    }
    
    // MARK: - Bikes Grid Section
    private var bikesGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if bikeManager.bikes.count > 1 {
                HStack {
                    Text("All Bikes")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
            }
            
            if bikeManager.isLoading {
                ProgressView("Loading bikes...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if bikeManager.bikes.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(bikeManager.bikes.filter { !$0.isPrimary }) { bike in
                        BikeCardView(bike: bike, isPrimary: false) {
                            selectedBike = bike
                            showingBikeDetail = true
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Add Bike",
                    icon: "plus.circle",
                    color: .blue
                ) {
                    showingAddBike = true
                }
                
                QuickActionButton(
                    title: "Maintenance",
                    icon: "wrench.and.screwdriver",
                    color: .orange
                ) {
                    if let primaryBike = bikeManager.primaryBike {
                        selectedBikeForMaintenance = primaryBike
                        showingMaintenanceView = true
                    } else if let firstBike = bikeManager.bikes.first {
                        selectedBikeForMaintenance = firstBike
                        showingMaintenanceView = true
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "car.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Bikes Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Add your first bike to get started with your digital garage")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                showingAddBike = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Your First Bike")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Computed Properties
    private var totalMileage: String {
        let total = bikeManager.bikes.reduce(0) { $0 + $1.currentMileage }
        return "\(total)"
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
}

// MARK: - Bike Card View
struct BikeCardView: View {
    let bike: Bike
    let isPrimary: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Bike image or placeholder
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(12)
                    
                    if bike.photos.isEmpty {
                        VStack {
                            Image(systemName: bike.bikeType.icon)
                                .font(.title)
                                .foregroundColor(.gray)
                            Text(bike.bikeType.displayName)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else {
                        AsyncImage(url: URL(string: bike.photos.first ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                        }
                        .clipped()
                        .cornerRadius(12)
                    }
                    
                    // Primary badge
                    if isPrimary {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .padding(8)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                                    .padding(.top, 8)
                                    .padding(.trailing, 8)
                            }
                            Spacer()
                        }
                    }
                }
                
                // Bike info
                VStack(alignment: .leading, spacing: 4) {
                    Text(bike.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let make = bike.make, let model = bike.model {
                        Text("\(make) \(model)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if let year = bike.year {
                        Text("\(year)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "speedometer")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(bike.currentMileage) mi")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text(bike.bikeType.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding()
            .background(adaptiveCardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            .foregroundColor(color)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ViewFriendsGarageView: View {
    @State private var username: String = ""
    @State private var bikes: [Bike] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            Section(header: Text("Friend")) {
                HStack {
                    TextField("Username", text: $username)
                    Button("Load") { load() }
                        .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            if isLoading { ProgressView() }
            if let errorMessage { Text(errorMessage).foregroundColor(.red) }
            Section(header: Text("Bikes")) {
                if bikes.isEmpty {
                    Text("No bikes found")
                } else {
                    ForEach(bikes) { bike in
                        VStack(alignment: .leading) {
                            Text(bike.name).font(.headline)
                            Text([bike.make, bike.model].compactMap { $0 }.joined(separator: " "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Friend's Garage")
    }
    
    private func load() {
        isLoading = true
        errorMessage = nil
        let cleaned = username.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "@", with: "")
        NetworkManager.shared.getUserByUsername(cleaned)
            .flatMap { resp in
                NetworkManager.shared.getBikes(for: resp.user.id)
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    let message = error.localizedDescription
                    if message.contains("HTTP 404") {
                        // User not found
                        self.bikes = []
                        self.errorMessage = "User not found"
                    } else if message.contains("HTTP 500") {
                        // Backend error – present friendly message and empty list
                        self.bikes = []
                        self.errorMessage = "Unable to load garage right now. Please try again later."
                    } else {
                        self.errorMessage = message
                    }
                }
            }, receiveValue: { bikes in
                self.bikes = bikes
            })
            .store(in: &cancellables)
    }
    
    @State private var cancellables = Set<AnyCancellable>()
}

#Preview {
    DigitalGarageView()
        .environmentObject(BikeManager.shared)
} 