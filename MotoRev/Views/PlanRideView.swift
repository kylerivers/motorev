import SwiftUI

struct PlanRideView: View {
    @EnvironmentObject var groupManager: GroupRideManager
    @State private var rideName: String = ""
    @State private var description: String = ""
    @State private var isPrivate: Bool = true
    @State private var inviteUsername: String = ""
    @State private var status: String?
    
    var body: some View {
        Form {
            Section(header: Text("Ride Details")) {
                TextField("Name", text: $rideName)
                TextField("Description", text: $description)
                Toggle("Private ride", isOn: $isPrivate)
            }
            Section(header: Text("Invite")) {
                HStack {
                    TextField("Username", text: $inviteUsername)
                    Button("Invite") { invite() }
                        .disabled(inviteUsername.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            if let status { Text(status).foregroundColor(.secondary) }
            Button("Create Ride") { createRide() }
                .disabled(rideName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .navigationTitle("Plan Ride")
    }
    
    private func createRide() {
        groupManager.createGroupRide(name: rideName, description: description, isPrivate: isPrivate) { result in
            switch result {
            case .success:
                status = "Ride created"
            case .failure(let e):
                status = e.localizedDescription
            }
        }
    }
    
    private func invite() {
        groupManager.inviteUser(inviteUsername) { (_: Result<Void, Error>) in }
        inviteUsername = ""
        status = "Invite sent"
    }
} 