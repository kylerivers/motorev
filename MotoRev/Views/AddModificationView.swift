import SwiftUI
import Combine

struct AddModificationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var bikeManager: BikeManager
    @State private var cancellables = Set<AnyCancellable>()
    @State private var name = ""
    @State private var description = ""
    @State private var category: BikeModification.ModificationCategory = .performance
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
                        ForEach(BikeModification.ModificationCategory.allCases, id: \.self) { category in
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
        
        // Format installation date as yyyy-MM-dd for model/string storage
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        let installDateString = fmt.string(from: installationDate)

        let modification = BikeModification(
            id: UUID(),
            name: name,
            description: description.isEmpty ? nil : description,
            cost: Double(cost),
            installDate: installDateString,
            category: category
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

#Preview {
    AddModificationView(bike: Bike(
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
        notes: "",
        isPrimary: true,
        photos: [],
        modifications: [],
        createdAt: "2024-01-15T00:00:00Z",
        updatedAt: "2024-01-15T00:00:00Z"
    ))
        .environmentObject(BikeManager.shared)
} 