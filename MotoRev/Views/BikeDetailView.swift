import SwiftUI
import Combine

struct BikeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var bikeManager: BikeManager
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @State private var showingActionSheet = false
    @State private var showingMaintenanceView = false
    @State private var showingAddModification = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    let bike: Bike
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Photos carousel
                    photosCarousel
                    
                    // Basic info card
                    basicInfoCard
                    
                    // Specifications card
                    specificationsCard
                    
                    // Modifications section
                    modificationsSection
                    
                    // Maintenance section (placeholder for future)
                    maintenanceSection
                    
                    // Quick actions
                    quickActionsSection
                }
                .padding()
            }
            .navigationTitle(bike.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingActionSheet = true
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingEditView) {
                AddEditBikeView(bike: bike)
            }
            .sheet(isPresented: $showingMaintenanceView) {
                MaintenanceView(bike: bike)
            }
            .sheet(isPresented: $showingAddModification) {
                AddModificationInlineView(bike: bike)
            }
            .alert("Delete Bike", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteBike()
                }
            } message: {
                Text("Are you sure you want to delete \(bike.name)? This action cannot be undone.")
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog("Bike Options", isPresented: $showingActionSheet) {
                Button("Edit Bike") {
                    showingEditView = true
                }
                
                if !bike.isPrimary {
                    Button("Set as Primary") {
                        setPrimaryBike()
                    }
                }
                
                Button("Delete Bike", role: .destructive) {
                    showingDeleteAlert = true
                }
                
                Button("Cancel", role: .cancel) { }
            }
        }
        .onAppear {
            bikeManager.fetchMaintenanceRecords(for: bike.id)
        }
    }
    
    // MARK: - Photos Carousel
    private var photosCarousel: some View {
        Group {
            if !bike.photos.isEmpty {
                TabView {
                    ForEach(bike.photos, id: \.self) { photoUrl in
                        AsyncImage(url: URL(string: photoUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .overlay(
                                    ProgressView()
                                )
                        }
                        .frame(height: 250)
                        .clipped()
                        .cornerRadius(12)
                    }
                }
                .frame(height: 250)
                .tabViewStyle(PageTabViewStyle())
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(height: 250)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("No photos")
                                .foregroundColor(.gray)
                        }
                    )
            }
        }
    }
    
    // MARK: - Basic Info Card
    private var basicInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Basic Information")
                    .font(.headline)
                
                Spacer()
                
                if bike.isPrimary {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("Primary")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                InfoRow(title: "Year", value: bike.year != nil ? String(bike.year!) : "Not specified")
                InfoRow(title: "Make", value: bike.make ?? "Not specified")
                InfoRow(title: "Model", value: bike.model ?? "Not specified")
                InfoRow(title: "Color", value: bike.color ?? "Not specified")
            }
            
            if let notes = bike.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(notes)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Specifications Card
    private var specificationsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Specifications")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: bike.bikeType.icon)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(bike.bikeType.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Spacer()
                }
                
                InfoRow(title: "Engine", value: bike.engineSize ?? "Not specified")
                InfoRow(title: "Mileage", value: "\(bike.currentMileage) miles")
                
                if let purchaseDate = bike.purchaseDate {
                    InfoRow(title: "Purchase Date", value: formatDate(purchaseDate))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Modifications Section
    private var modificationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Modifications")
                    .font(.headline)
                
                Spacer()
                
                Button("Add Mod") {
                    showingAddModification = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if !bike.modifications.isEmpty {
                LazyVStack(spacing: 12) {
                    ForEach(bike.modifications) { modification in
                        ModificationRow(modification: modification)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No modifications added")
                        .foregroundColor(.gray)
                    Text("Add modifications to track your bike's upgrades")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Maintenance Section
    private var maintenanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Maintenance")
                    .font(.headline)
                
                Spacer()
                
                Button("View All") {
                    showingMaintenanceView = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Show recent maintenance records or empty state
            if bikeManager.maintenanceRecords.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "wrench.adjustable")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No maintenance records yet")
                        .foregroundColor(.gray)
                    Text("Keep track of oil changes, services, and repairs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Add First Record") {
                        showingMaintenanceView = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                // Show most recent maintenance records
                VStack(spacing: 8) {
                    ForEach(Array(bikeManager.maintenanceRecords.prefix(3))) { record in
                        HStack {
                            Image(systemName: record.maintenanceType.icon)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(formatDate(record.serviceDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if let cost = record.cost {
                                Text("$\(cost, specifier: "%.0f")")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            Button {
                showingEditView = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text("Edit Bike")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            if !bike.isPrimary {
                Button {
                    setPrimaryBike()
                } label: {
                    HStack {
                        Image(systemName: "star")
                        Text("Set as Primary")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func deleteBike() {
        bikeManager.deleteBike(bike)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to delete bike: \(error)")
                        errorMessage = error.localizedDescription
                        showingErrorAlert = true
                    }
                },
                receiveValue: { _ in
                    dismiss()
                }
            )
            .store(in: &cancellables)
    }
    
    private func setPrimaryBike() {
        bikeManager.setBikePrimary(bike)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        
        return dateString
    }
}

// MARK: - Supporting Views
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct ModificationRow: View {
    let modification: BikeModification
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(modification.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let description = modification.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 16) {
                    if let cost = modification.cost {
                        Text("$\(String(format: "%.0f", cost))")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    if let installDate = modification.installDate {
                        Text(installDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Text(modification.category.rawValue.capitalized)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(6)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Inline Add Modification View (scope-local to avoid symbol resolution issues)
struct AddModificationInlineView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var bikeManager: BikeManager
    @State private var name: String = ""
    @State private var descriptionText: String = ""
    @State private var category: BikeModification.ModificationCategory = .other
    @State private var installationDate = Date()
    @State private var costText: String = ""
    let bike: Bike

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic")) {
                    TextField("Name", text: $name)
                    TextField("Description", text: $descriptionText, axis: .vertical)
                }
                Section(header: Text("Details")) {
                    Picker("Category", selection: $category) {
                        ForEach(BikeModification.ModificationCategory.allCases, id: \.self) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                    DatePicker("Installed", selection: $installationDate, displayedComponents: .date)
                    TextField("Cost ($)", text: $costText).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Modification")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }.disabled(name.isEmpty)
                }
            }
        }
    }

    private func save() {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        let mod = BikeModification(
            id: UUID(),
            name: name,
            description: descriptionText.isEmpty ? nil : descriptionText,
            cost: Double(costText),
            installDate: fmt.string(from: installationDate),
            category: category
        )
        _ = bikeManager.addModification(to: bike.id, modification: mod)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in dismiss() })
    }
}

#Preview {
    BikeDetailView(bike: Bike(
        id: 1,
        userId: 1,
        name: "My R1",
        year: 2024,
        make: "Yamaha",
        model: "YZF-R1",
        color: "Blue",
        engineSize: "998cc",
        bikeType: .sport,
        currentMileage: 1500,
        purchaseDate: "2024-01-15",
        notes: "Amazing bike with great performance",
        isPrimary: true,
        photos: [],
        modifications: [],
        createdAt: "2024-01-15T00:00:00Z",
        updatedAt: "2024-01-15T00:00:00Z"
    ))
    .environmentObject(BikeManager.shared)
} 