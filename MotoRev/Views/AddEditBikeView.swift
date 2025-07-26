import SwiftUI
import PhotosUI
import Combine

struct AddEditBikeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var bikeManager: BikeManager
    @State private var cancellables = Set<AnyCancellable>()
    @State private var name = ""
    @State private var year = ""
    @State private var make = ""
    @State private var model = ""
    @State private var color = ""
    @State private var engineSize = ""
    @State private var bikeType: Bike.BikeType = .other
    @State private var currentMileage = ""
    @State private var notes = ""
    @State private var isPrimary = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoData: [Data] = []
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var purchaseDate: Date = Date()
    @State private var showingDatePicker = false
    
    let bike: Bike?
    
    init(bike: Bike? = nil) {
        self.bike = bike
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Photos section
                    photosSection
                    
                    // Basic Info section
                    basicInfoSection
                    
                    // Specifications section
                    specificationsSection
                    
                    // Additional Info section
                    additionalInfoSection
                }
                .padding()
            }
            .navigationTitle(bike == nil ? "Add Bike" : "Edit Bike")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(bike == nil ? "Add" : "Save") {
                        saveBike()
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
            .onAppear {
                loadBikeData()
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Photos Section
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(.headline)
            
            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                VStack(spacing: 8) {
                    Image(systemName: "camera.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    Text("Add Photos")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    Text("Up to 5 photos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .onChange(of: selectedPhotos) { _, photos in
                loadSelectedPhotos(photos)
            }
            
            if !photoData.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(photoData.enumerated()), id: \.offset) { index, data in
                            if let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipped()
                                    .cornerRadius(8)
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            photoData.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Color.white, in: Circle())
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Basic Info Section
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Information")
                .font(.headline)
            
            VStack(spacing: 12) {
                TextField("Bike Name *", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack(spacing: 12) {
                    TextField("Year", text: $year)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                    
                    TextField("Make", text: $make)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                TextField("Model", text: $model)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack(spacing: 12) {
                    TextField("Color", text: $color)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Engine Size", text: $engineSize)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .placeholder(when: engineSize.isEmpty) {
                            Text("e.g., 600cc")
                                .foregroundColor(.gray)
                        }
                }
            }
        }
    }
    
    // MARK: - Specifications Section
    private var specificationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Specifications")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Bike Type Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bike Type")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        ForEach(Bike.BikeType.allCases, id: \.self) { type in
                            Button {
                                bikeType = type
                            } label: {
                                HStack {
                                    Image(systemName: type.icon)
                                    Text(type.displayName)
                                    if bikeType == type {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: bikeType.icon)
                            Text(bikeType.displayName)
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                
                TextField("Current Mileage", text: $currentMileage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
            }
        }
    }
    
    // MARK: - Additional Info Section
    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Additional Information")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Purchase Date
                VStack(alignment: .leading, spacing: 8) {
                    Text("Purchase Date")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: { showingDatePicker = true }) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text(purchaseDate, style: .date)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                
                TextField("Notes", text: $notes, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
                
                Toggle("Set as Primary Bike", isOn: $isPrimary)
                    .toggleStyle(SwitchToggleStyle())
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationView {
                DatePicker(
                    "Purchase Date",
                    selection: $purchaseDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .navigationTitle("Select Purchase Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingDatePicker = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingDatePicker = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Functions
    private func loadBikeData() {
        guard let bike = bike else { return }
        
        name = bike.name
        year = bike.year != nil ? String(bike.year!) : ""
        make = bike.make ?? ""
        model = bike.model ?? ""
        color = bike.color ?? ""
        engineSize = bike.engineSize ?? ""
        bikeType = bike.bikeType
        currentMileage = String(bike.currentMileage)
        purchaseDate = bike.purchaseDate ?? Date()
        notes = bike.notes ?? ""
        isPrimary = bike.isPrimary
    }
    
    private func loadSelectedPhotos(_ photos: [PhotosPickerItem]) {
        photoData.removeAll()
        
        for photo in photos {
            photo.loadTransferable(type: Data.self) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let data):
                        if let data = data {
                            photoData.append(data)
                        }
                    case .failure(let error):
                        print("Error loading photo: \(error)")
                    }
                }
            }
        }
    }
    
    private func saveBike() {
        guard !name.isEmpty else { return }
        
        isLoading = true
        
        // Convert photo data to UIImages
        let images = photoData.compactMap { data -> UIImage? in
            return UIImage(data: data)
        }
        
        if let existingBike = bike {
            // Update existing bike
            bikeManager.updateBike(
                bikeId: existingBike.id,
                name: name,
                year: Int(year),
                make: make.isEmpty ? nil : make,
                model: model.isEmpty ? nil : model,
                color: color.isEmpty ? nil : color,
                engineSize: engineSize.isEmpty ? nil : engineSize,
                bikeType: bikeType,
                currentMileage: Int(currentMileage) ?? 0,
                purchaseDate: purchaseDate,
                notes: notes.isEmpty ? nil : notes,
                isPrimary: isPrimary,
                photos: images,
                modifications: existingBike.modifications
            )
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
        } else {
            // Create new bike
            bikeManager.createBike(
                name: name,
                year: Int(year),
                make: make.isEmpty ? nil : make,
                model: model.isEmpty ? nil : model,
                color: color.isEmpty ? nil : color,
                engineSize: engineSize.isEmpty ? nil : engineSize,
                bikeType: bikeType,
                currentMileage: Int(currentMileage) ?? 0,
                purchaseDate: purchaseDate,
                notes: notes.isEmpty ? nil : notes,
                isPrimary: isPrimary,
                photos: images,
                modifications: []
            )
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
}

// MARK: - Extensions
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
            
            ZStack(alignment: alignment) {
                placeholder().opacity(shouldShow ? 1 : 0)
                self
            }
        }
}

#Preview {
    AddEditBikeView()
        .environmentObject(BikeManager.shared)
} 