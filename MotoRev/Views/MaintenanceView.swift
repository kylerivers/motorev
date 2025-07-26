import SwiftUI

struct MaintenanceView: View {
    let bike: Bike
    @ObservedObject private var bikeManager = BikeManager.shared
    @State private var showingAddMaintenance = false
    @State private var selectedRecord: MaintenanceRecord?
    
    var body: some View {
        NavigationView {
            VStack {
                if bikeManager.isLoadingMaintenance {
                    ProgressView("Loading maintenance records...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if bikeManager.maintenanceRecords.isEmpty {
                    emptyStateView
                } else {
                    maintenanceList
                }
            }
            .navigationTitle("Maintenance")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddMaintenance = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddMaintenance) {
                AddEditMaintenanceView(bike: bike)
            }
            .sheet(item: $selectedRecord) { record in
                AddEditMaintenanceView(bike: bike, existingRecord: record)
            }
        }
        .onAppear {
            bikeManager.fetchMaintenanceRecords(for: bike.id)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Maintenance Records")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Keep track of your bike's maintenance history. Add oil changes, tire checks, and more.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Add First Record") {
                showingAddMaintenance = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var maintenanceList: some View {
        List {
            ForEach(groupedRecords.keys.sorted(by: >), id: \.self) { year in
                Section(header: Text("\(year)")) {
                    ForEach(groupedRecords[year] ?? []) { record in
                        MaintenanceRecordRow(record: record) {
                            selectedRecord = record
                        }
                    }
                    .onDelete { indexSet in
                        let recordsForYear = groupedRecords[year] ?? []
                        for index in indexSet {
                            let record = recordsForYear[index]
                            bikeManager.deleteMaintenanceRecord(record.id, bikeId: bike.id)
                        }
                    }
                }
            }
        }
        .refreshable {
            bikeManager.fetchMaintenanceRecords(for: bike.id)
        }
    }
    
    private var groupedRecords: [Int: [MaintenanceRecord]] {
        Dictionary(grouping: bikeManager.maintenanceRecords) { record in
            let year = Calendar.current.component(.year, from: dateFromString(record.serviceDate))
            return year
        }
    }
    
    private func dateFromString(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString) ?? Date()
    }
}

struct MaintenanceRecordRow: View {
    let record: MaintenanceRecord
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Icon
                Image(systemName: record.maintenanceType.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(record.maintenanceType.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let mileage = record.mileageAtService {
                        Text("\(mileage) miles")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formattedDate(record.serviceDate))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    if let cost = record.cost {
                        Text("$\(cost, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    if !record.completed {
                        Text("Pending")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formattedDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    MaintenanceView(bike: Bike(
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
    ))
} 