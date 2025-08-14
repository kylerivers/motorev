import Foundation
import Combine
import UIKit

class BikeManager: ObservableObject {
    static let shared = BikeManager()
    
    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var bikes: [Bike] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var primaryBike: Bike? {
        return bikes.first { $0.isPrimary }
    }
    
    private init() {
        // Load bikes when the user logs in
        networkManager.$isLoggedIn
            .sink { [weak self] isLoggedIn in
                if isLoggedIn {
                    self?.loadBikes()
                } else {
                    self?.bikes = []
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadBikes() {
        guard networkManager.isLoggedIn else { return }
        
        isLoading = true
        errorMessage = nil
        
        networkManager.getBikes()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        print("❌ Failed to load bikes: \(error)")
                    }
                },
                receiveValue: { [weak self] (response: BikesResponse) in
                    self?.bikes = response.bikes
                    print("✅ Loaded \(response.bikes.count) bikes")
                }
            )
            .store(in: &cancellables)
    }
    
    func createBike(
        name: String,
        year: Int? = nil,
        make: String? = nil,
        model: String? = nil,
        color: String? = nil,
        engineSize: String? = nil,
        bikeType: Bike.BikeType = .other,
        currentMileage: Int = 0,
        purchaseDate: String? = nil,
        notes: String? = nil,
        isPrimary: Bool = false,
        photos: [UIImage] = [],
        modifications: [BikeModification] = []
    ) -> AnyPublisher<Bike, Error> {
        
        // Convert images to base64
        let photoStrings = photos.compactMap { image in
            image.jpegData(compressionQuality: 0.7)?.base64EncodedString()
        }
        
        let request = CreateBikeRequest(
            name: name,
            year: year,
            make: make,
            model: model,
            color: color,
            engineSize: engineSize,
            bikeType: bikeType.rawValue,
            currentMileage: currentMileage,
            purchaseDate: purchaseDate,
            notes: notes,
            isPrimary: isPrimary,
            photos: photoStrings.isEmpty ? nil : photoStrings,
            modifications: modifications.isEmpty ? nil : modifications
        )
        
        return networkManager.createBike(bike: request)
            .map { (response: BikeResponse) -> Bike in
                // Add the new bike to our local list
                DispatchQueue.main.async {
                    self.bikes.append(response.bike)
                    self.bikes.sort { $0.isPrimary && !$1.isPrimary }
                }
                return response.bike
            }
            .eraseToAnyPublisher()
    }
    
    func updateBike(
        bikeId: Int,
        name: String,
        year: Int? = nil,
        make: String? = nil,
        model: String? = nil,
        color: String? = nil,
        engineSize: String? = nil,
        bikeType: Bike.BikeType = .other,
        currentMileage: Int = 0,
        purchaseDate: String? = nil,
        notes: String? = nil,
        isPrimary: Bool = false,
        photos: [UIImage] = [],
        modifications: [BikeModification] = []
    ) -> AnyPublisher<Bike, Error> {
        
        // Convert images to base64
        let photoStrings = photos.compactMap { image in
            image.jpegData(compressionQuality: 0.7)?.base64EncodedString()
        }
        
        let request = UpdateBikeRequest(
            name: name,
            year: year,
            make: make,
            model: model,
            color: color,
            engineSize: engineSize,
            bikeType: bikeType.rawValue,
            currentMileage: currentMileage,
            purchaseDate: purchaseDate,
            notes: notes,
            isPrimary: isPrimary,
            photos: photoStrings.isEmpty ? nil : photoStrings,
            modifications: modifications.isEmpty ? nil : modifications
        )
        
        return networkManager.updateBike(bikeId: String(bikeId), bike: request)
            .map { (response: BikeResponse) -> Bike in
                // Update the bike in our local list
                DispatchQueue.main.async {
                    if let index = self.bikes.firstIndex(where: { $0.id == bikeId }) {
                        self.bikes[index] = response.bike
                        self.bikes.sort { $0.isPrimary && !$1.isPrimary }
                    }
                }
                return response.bike
            }
            .eraseToAnyPublisher()
    }
    
    func deleteBike(_ bike: Bike) -> AnyPublisher<Void, Error> {
        return networkManager.deleteBike(bikeId: String(bike.id))
            .map { (_: MessageResponse) -> Void in
                // Remove the bike from our local list
                DispatchQueue.main.async {
                    self.bikes.removeAll { $0.id == bike.id }
                }
                return ()
            }
            .eraseToAnyPublisher()
    }
    
    func setBikePrimary(_ bike: Bike) {
        guard !bike.isPrimary else { return }
        
        updateBike(
            bikeId: bike.id,
            name: bike.name,
            year: bike.year,
            make: bike.make,
            model: bike.model,
            color: bike.color,
            engineSize: bike.engineSize,
            bikeType: bike.bikeType,
            currentMileage: bike.currentMileage,
            purchaseDate: bike.purchaseDate,
            notes: bike.notes,
            isPrimary: true,
            photos: [], // Keep existing photos
            modifications: bike.modifications
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ Failed to set primary bike: \(error)")
                }
            },
            receiveValue: { _ in
                print("✅ Set bike as primary")
            }
        )
        .store(in: &cancellables)
    }
    
    func updateMileage(for bike: Bike, newMileage: Int) {
        updateBike(
            bikeId: bike.id,
            name: bike.name,
            year: bike.year,
            make: bike.make,
            model: bike.model,
            color: bike.color,
            engineSize: bike.engineSize,
            bikeType: bike.bikeType,
            currentMileage: newMileage,
            purchaseDate: bike.purchaseDate,
            notes: bike.notes,
            isPrimary: bike.isPrimary,
            photos: [], // Keep existing photos
            modifications: bike.modifications
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ Failed to update mileage: \(error)")
                }
            },
            receiveValue: { _ in
                print("✅ Updated bike mileage to \(newMileage)")
            }
        )
        .store(in: &cancellables)
    }
    
    // MARK: - Maintenance Tracking
    @Published var maintenanceRecords: [MaintenanceRecord] = []
    @Published var isLoadingMaintenance = false
    
    func fetchMaintenanceRecords(for bikeId: Int) {
        isLoadingMaintenance = true
        
        guard let url = URL(string: "\(networkManager.baseURL)/bikes/\(bikeId)/maintenance") else {
            isLoadingMaintenance = false
            return
        }
        
        networkManager.makeAuthenticatedRequest(url: url, method: "GET", body: EmptyBody())
            .sink(
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        self?.isLoadingMaintenance = false
                    }
                    if case .failure(let error) = completion {
                        print("Error fetching maintenance records: \(error)")
                    }
                },
                receiveValue: { [weak self] (response: MaintenanceRecordsResponse) in
                    DispatchQueue.main.async {
                        if response.success {
                            self?.maintenanceRecords = response.records
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func createMaintenanceRecord(_ request: CreateMaintenanceRequest) {
        isLoadingMaintenance = true
        
        guard let url = URL(string: "\(networkManager.baseURL)/bikes/\(request.bikeId)/maintenance") else {
            isLoadingMaintenance = false
            return
        }
        
        networkManager.makeAuthenticatedRequest(url: url, method: "POST", body: request)
            .sink(
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        self?.isLoadingMaintenance = false
                    }
                    if case .failure(let error) = completion {
                        print("Error creating maintenance record: \(error)")
                    }
                },
                receiveValue: { [weak self] (response: MaintenanceRecordResponse) in
                    DispatchQueue.main.async {
                        if response.success {
                            // Refresh maintenance records
                            self?.fetchMaintenanceRecords(for: request.bikeId)
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func updateMaintenanceRecord(_ recordId: Int, bikeId: Int, request: UpdateMaintenanceRequest) {
        isLoadingMaintenance = true
        
        guard let url = URL(string: "\(networkManager.baseURL)/bikes/\(bikeId)/maintenance/\(recordId)") else {
            isLoadingMaintenance = false
            return
        }
        
        networkManager.makeAuthenticatedRequest(url: url, method: "PUT", body: request)
            .sink(
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        self?.isLoadingMaintenance = false
                    }
                    if case .failure(let error) = completion {
                        print("Error updating maintenance record: \(error)")
                    }
                },
                receiveValue: { [weak self] (response: MaintenanceRecordResponse) in
                    DispatchQueue.main.async {
                        if response.success {
                            // Refresh maintenance records
                            self?.fetchMaintenanceRecords(for: bikeId)
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func deleteMaintenanceRecord(_ recordId: Int, bikeId: Int) {
        isLoadingMaintenance = true
        
        guard let url = URL(string: "\(networkManager.baseURL)/bikes/\(bikeId)/maintenance/\(recordId)") else {
            isLoadingMaintenance = false
            return
        }
        
        networkManager.makeAuthenticatedRequest(url: url, method: "DELETE", body: EmptyBody())
            .sink(
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        self?.isLoadingMaintenance = false
                    }
                    if case .failure(let error) = completion {
                        print("Error deleting maintenance record: \(error)")
                    }
                },
                receiveValue: { [weak self] (response: MaintenanceRecordResponse) in
                    DispatchQueue.main.async {
                        if response.success {
                            // Refresh maintenance records
                            self?.fetchMaintenanceRecords(for: bikeId)
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func addModification(to bikeId: Int, modification: BikeModification) -> AnyPublisher<Bike, Error> {
        guard let url = URL(string: "\(networkManager.baseURL)/bikes/\(bikeId)/modifications") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        // Convert installDate String? -> Date (fallback to today)
        let installationDate: Date = {
            if let str = modification.installDate {
                if str.contains("T") {
                    let iso = ISO8601DateFormatter()
                    if let d = iso.date(from: str) { return d }
                }
                let fmt = DateFormatter()
                fmt.calendar = Calendar(identifier: .gregorian)
                fmt.locale = Locale(identifier: "en_US_POSIX")
                fmt.dateFormat = "yyyy-MM-dd"
                if let d = fmt.date(from: str) { return d }
            }
            return Date()
        }()
        
        let request = CreateModificationRequest(
            name: modification.name,
            description: modification.description,
            category: modification.category.rawValue,
            installationDate: installationDate,
            cost: modification.cost ?? 0,
            installer: nil,
            warrantyInfo: nil
        )
        
        return networkManager.makeAuthenticatedRequest(url: url, method: "POST", body: request)
            .map { (response: BikeResponse) -> Bike in
                // Update the bike in our local list
                DispatchQueue.main.async {
                    if let index = self.bikes.firstIndex(where: { $0.id == bikeId }) {
                        self.bikes[index] = response.bike
                    }
                }
                return response.bike
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - NetworkManager Extension
private extension NetworkManager {
    func makeAuthenticatedRequest<T: Codable, U: Codable>(url: URL, method: String, body: T? = nil) -> AnyPublisher<U, Error> {
        guard let token = authToken else {
            return Fail(error: NetworkError.notAuthenticated).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Only include body for non-GET requests
        if method != "GET", let body = body {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                request.httpBody = try encoder.encode(body)
            } catch {
                return Fail(error: error).eraseToAnyPublisher()
            }
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                if httpResponse.statusCode >= 400 {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                        throw NetworkError.serverError(errorResponse.error)
                    } else {
                        throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                    }
                }
                
                return data
            }
            .decode(type: U.self, decoder: {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return decoder
            }())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
} 