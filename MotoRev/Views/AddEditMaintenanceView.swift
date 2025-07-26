import SwiftUI
import PhotosUI

struct AddEditMaintenanceView: View {
    let bike: Bike
    @EnvironmentObject var bikeManager: BikeManager
    let existingRecord: MaintenanceRecord?
    
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedMaintenanceType: MaintenanceRecord.MaintenanceType = .oilChange
    @State private var description = ""
    @State private var cost = ""
    @State private var mileageAtService = ""
    @State private var serviceDate = Date()
    @State private var nextServiceMileage = ""
    @State private var nextServiceDate = Date()
    @State private var shopName = ""
    @State private var partsUsed: [MaintenancePart] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photos: [UIImage] = []
    @State private var reminderEnabled = true
    @State private var completed = true
    @State private var showingDeleteAlert = false
    
    private var isEditing: Bool {
        existingRecord != nil
    }
    
    init(bike: Bike, existingRecord: MaintenanceRecord? = nil) {
        self.bike = bike
        self.existingRecord = existingRecord
    }
    
    var body: some View {
        NavigationView {
            Form {
                basicInfoSection
                detailsSection
                partsSection
                photosSection
                optionsSection
            }
            .navigationTitle(isEditing ? "Edit Maintenance" : "Add Maintenance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Update" : "Save") {
                        saveRecord()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .alert("Delete Record", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let record = existingRecord {
                        bikeManager.deleteMaintenanceRecord(record.id, bikeId: bike.id)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this maintenance record? This action cannot be undone.")
            }
        }
        .onAppear {
            loadExistingRecord()
        }
        .onChange(of: selectedMaintenanceType) { _, newType in
            if title.isEmpty || title == selectedMaintenanceType.displayName {
                title = newType.displayName
            }
        }
        .onChange(of: selectedPhotos) { _, photos in
            Task {
                await loadPhotos()
            }
        }
    }
    
    private var basicInfoSection: some View {
        Section("Basic Information") {
            Picker("Maintenance Type", selection: $selectedMaintenanceType) {
                ForEach(MaintenanceRecord.MaintenanceType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.icon)
                        .tag(type)
                }
            }
            
            TextField("Title", text: $title)
            
            TextField("Description (optional)", text: $description, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    private var detailsSection: some View {
        Section("Service Details") {
            HStack {
                Text("Cost")
                Spacer()
                TextField("$0.00", text: $cost)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
            }
            
            HStack {
                Text("Mileage")
                Spacer()
                TextField("Current mileage", text: $mileageAtService)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 120)
            }
            
            DatePicker("Service Date", selection: $serviceDate, displayedComponents: .date)
            
            HStack {
                Text("Next Service Mileage")
                Spacer()
                TextField("Optional", text: $nextServiceMileage)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 120)
            }
            
            DatePicker("Next Service Date", selection: $nextServiceDate, displayedComponents: .date)
            
            TextField("Shop Name (optional)", text: $shopName)
        }
    }
    
    private var partsSection: some View {
        Section("Parts Used") {
            ForEach(partsUsed) { part in
                VStack(alignment: .leading, spacing: 4) {
                    Text(part.name)
                        .font(.headline)
                    if let brand = part.brand {
                        Text("Brand: \(brand)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let partNumber = part.partNumber {
                        Text("Part #: \(partNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Qty: \(part.quantity)")
                        Spacer()
                        if let cost = part.cost {
                            Text("$\(cost, specifier: "%.2f")")
                                .foregroundColor(.green)
                        }
                    }
                    .font(.caption)
                }
            }
            .onDelete(perform: deletePart)
            
            Button("Add Part") {
                partsUsed.append(MaintenancePart(name: "New Part"))
            }
        }
    }
    
    private var photosSection: some View {
        Section("Photos") {
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 5,
                matching: .images
            ) {
                Label("Add Photos", systemImage: "photo")
            }
            
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(photos.indices, id: \.self) { index in
                            Image(uiImage: photos[index])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipped()
                                .cornerRadius(8)
                                .overlay(
                                    Button {
                                        photos.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .background(Color.white, in: Circle())
                                    },
                                    alignment: .topTrailing
                                )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var optionsSection: some View {
        Section("Options") {
            Toggle("Reminder Enabled", isOn: $reminderEnabled)
            Toggle("Completed", isOn: $completed)
            
            if isEditing {
                Button("Delete Record", role: .destructive) {
                    showingDeleteAlert = true
                }
            }
        }
    }
    
    private func loadExistingRecord() {
        guard let record = existingRecord else {
            // Set default title based on maintenance type
            title = selectedMaintenanceType.displayName
            return
        }
        
        title = record.title
        selectedMaintenanceType = record.maintenanceType
        description = record.description ?? ""
        cost = record.cost?.description ?? ""
        mileageAtService = record.mileageAtService?.description ?? ""
        serviceDate = dateFromString(record.serviceDate)
        nextServiceMileage = record.nextServiceMileage?.description ?? ""
        if let nextDate = record.nextServiceDate {
            nextServiceDate = dateFromString(nextDate)
        }
        shopName = record.shopName ?? ""
        partsUsed = record.partsUsed
        reminderEnabled = record.reminderEnabled
        completed = record.completed
    }
    
    private func saveRecord() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if isEditing {
            guard let record = existingRecord else { return }
            
            let request = UpdateMaintenanceRequest(
                title: title,
                description: description.isEmpty ? nil : description,
                cost: Double(cost),
                mileageAtService: Int(mileageAtService),
                serviceDate: formatter.string(from: serviceDate),
                nextServiceMileage: Int(nextServiceMileage),
                nextServiceDate: formatter.string(from: nextServiceDate),
                shopName: shopName.isEmpty ? nil : shopName,
                partsUsed: partsUsed.isEmpty ? nil : partsUsed,
                photos: convertPhotosToBase64(),
                reminderEnabled: reminderEnabled,
                completed: completed
            )
            
            bikeManager.updateMaintenanceRecord(record.id, bikeId: bike.id, request: request)
        } else {
            let request = CreateMaintenanceRequest(
                bikeId: bike.id,
                maintenanceType: selectedMaintenanceType.rawValue,
                title: title,
                description: description.isEmpty ? nil : description,
                cost: Double(cost),
                mileageAtService: Int(mileageAtService),
                serviceDate: formatter.string(from: serviceDate),
                nextServiceMileage: Int(nextServiceMileage),
                nextServiceDate: formatter.string(from: nextServiceDate),
                shopName: shopName.isEmpty ? nil : shopName,
                partsUsed: partsUsed.isEmpty ? nil : partsUsed,
                photos: convertPhotosToBase64(),
                reminderEnabled: reminderEnabled,
                completed: completed
            )
            
            bikeManager.createMaintenanceRecord(request)
        }
        
        dismiss()
    }
    
    private func deletePart(at offsets: IndexSet) {
        partsUsed.remove(atOffsets: offsets)
    }
    
    private func loadPhotos() async {
        photos = []
        
        for item in selectedPhotos {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }
            
            await MainActor.run {
                photos.append(image)
            }
        }
    }
    
    private func convertPhotosToBase64() -> [String]? {
        guard !photos.isEmpty else { return nil }
        
        return photos.compactMap { image in
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
            return imageData.base64EncodedString()
        }
    }
    
    private func dateFromString(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString) ?? Date()
    }
}

#Preview {
    AddEditMaintenanceView(
        bike: Bike(
            id: 1,
            userId: 1,
            name: "My R1",
            year: 2024,
            make: "Yamaha",
            model: "YZF-R1",
            color: "Blue",
            engineSize: "998cc",
            bikeType: .sport,
            currentMileage: 5000,
            purchaseDate: nil,
            notes: nil,
            isPrimary: true,
            photos: [],
            modifications: [],
            createdAt: "",
            updatedAt: ""
        )
    )
    .environmentObject(BikeManager.shared)
} 