import SwiftUI

struct GroupRideBrowseView: View {
    @EnvironmentObject var networkManager: NetworkManager
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var groupRideManager: GroupRideManager
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var rides: [PublicRide] = []

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading group rides...")
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage).foregroundColor(.red)
                        Button("Retry", action: fetchRides)
                    }
                } else if rides.isEmpty {
                    ContentUnavailableView("No Group Rides", systemImage: "person.3.fill", description: Text("No public group rides available right now."))
                } else {
                    List(rides) { ride in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "person.3.fill").foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ride.name).font(.headline)
                                if let desc = ride.description, !desc.isEmpty { Text(desc).font(.caption).foregroundColor(.secondary).lineLimit(2) }
                                HStack(spacing: 8) {
                                    Text("Leader: \(ride.leaderName)").font(.caption).foregroundColor(.secondary)
                                    Text("\(ride.currentMembers)/\(ride.maxMembers ?? 20)").font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button("Join") { join(ride) }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Group Rides")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear(perform: fetchRides)
        }
    }

    private func join(_ ride: PublicRide) {
        groupRideManager.joinGroupRide(String(ride.id)) { result in
            switch result {
            case .success:
                dismiss()
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func fetchRides() {
        isLoading = true
        errorMessage = nil
        guard let token = networkManager.authToken, let url = URL(string: "\(networkManager.baseURL)/group-rides") else {
            isLoading = false
            errorMessage = "Not authenticated"
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error { errorMessage = error.localizedDescription; return }
                guard let http = response as? HTTPURLResponse, let data = data, (200..<300).contains(http.statusCode) else {
                    errorMessage = "Failed to load rides"
                    return
                }
                do {
                    let decoder = NetworkManager.createJSONDecoder()
                    let list = try decoder.decode(PublicRidesResponse.self, from: data)
                    self.rides = list.packs
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }.resume()
    }
}

// MARK: - API Models
struct PublicRidesResponse: Codable {
    let success: Bool
    let packs: [PublicRide]
    let pagination: Pagination?
}

struct Pagination: Codable { let page: Int?; let limit: Int?; let total: Int? }

struct PublicRide: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let leaderId: Int
    let leaderName: String
    let maxMembers: Int?
    let currentMembers: Int
    let isPrivate: Bool
    let status: String?
    let meetingPoint: String?
    let scheduledStart: String?
}


