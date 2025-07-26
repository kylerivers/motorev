import SwiftUI
import Combine

struct AddModificationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var bikeManager: BikeManager
    @State private var cancellables = Set<AnyCancellable>()
    @State private var name = ""
    @State private var description = ""
    @State private var category: Modification.Category = .performance
    @State private var installationDate = Date()
    @State private var cost: String = ""
    @State private var installer = ""
    @State private var warrantyInfo = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    let bike: Bike
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Basic Info Section
                    basicInfoSection
                    
                    // Details Section
                    detailsSection
                    
                    // Cost & Warranty Section
                    costWarrantySection
                }
                .padding()
            }
            .navigationTitle("Add Modification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveModification()
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Basic Info Section
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Information")
                .font(.headline)
            
            VStack(spacing: 12) {
                TextField("Modification Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Description", text: $description, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
                
                // Category Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("Category", selection: $category) {
                        ForEach(Modification.Category.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Details Section
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Installation Details")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Installation Date
                VStack(alignment: .leading, spacing: 8) {
                    Text("Installation Date")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    DatePicker("Installation Date", selection: $installationDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                TextField("Installer/Shop", text: $installer)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
    
    // MARK: - Cost & Warranty Section
    private var costWarrantySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cost & Warranty")
                .font(.headline)
            
            VStack(spacing: 12) {
                TextField("Cost ($)", text: $cost)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
                
                TextField("Warranty Information", text: $warrantyInfo, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(2...4)
            }
        }
    }
    
    // MARK: - Functions
    private func saveModification() {
        guard !name.isEmpty else { return }
        
        isLoading = true
        
        let modification = Modification(
            id: UUID(),
            name: name,
            description: description.isEmpty ? nil : description,
            category: category,
            installationDate: installationDate,
            cost: Double(cost) ?? 0.0,
            installer: installer.isEmpty ? nil : installer,
            warrantyInfo: warrantyInfo.isEmpty ? nil : warrantyInfo
        )
        
        bikeManager.addModification(to: bike.id, modification: modification)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        alertMessage = error.localizedDescription
                        showingAlert = true
                    }
                },
                receiveValue: { _ in
                    dismiss()
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Supporting Models
extension Modification {
    enum Category: String, CaseIterable, Codable {
        case performance = "performance"
        case aesthetic = "aesthetic"
        case safety = "safety"
        case comfort = "comfort"
        case storage = "storage"
        case lighting = "lighting"
        case exhaust = "exhaust"
        case suspension = "suspension"
        case brakes = "brakes"
        case other = "other"
        
        var displayName: String {
            switch self {
            case .performance: return "Performance"
            case .aesthetic: return "Aesthetic"
            case .safety: return "Safety"
            case .comfort: return "Comfort"
            case .storage: return "Storage"
            case .lighting: return "Lighting"
            case .exhaust: return "Exhaust"
            case .suspension: return "Suspension"
            case .brakes: return "Brakes"
            case .other: return "Other"
            }
        }
        
        var icon: String {
            switch self {
            case .performance: return "speedometer"
            case .aesthetic: return "paintbrush"
            case .safety: return "shield"
            case .comfort: return "person.fill"
            case .storage: return "bag"
            case .lighting: return "lightbulb"
            case .exhaust: return "flame"
            case .suspension: return "arrow.up.and.down"
            case .brakes: return "hand.raised"
            case .other: return "wrench.and.screwdriver"
            }
        }
    }
}

#Preview {
    AddModificationView(bike: Bike.sampleBikes[0])
        .environmentObject(BikeManager.shared)
} 