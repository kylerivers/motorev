import SwiftUI

struct NearbyAddView: View {
    @EnvironmentObject var nearby: NearbyAddManager
    @EnvironmentObject var social: SocialManager
    @State private var isOn = false
    
    var body: some View {
        VStack(spacing: 16) {
            Toggle("Nearby Discovery", isOn: Binding(get: { isOn }, set: { newVal in
                isOn = newVal
                if newVal {
                    nearby.start(username: social.currentUser?.username ?? "")
                } else {
                    nearby.stop()
                }
            }))
            .padding()
            List(nearby.nearbyUsernames, id: \.self) { name in
                HStack {
                    Text("@\(name)")
                    Spacer()
                    Button("Add") { social.addFriend(byUsername: name) }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Nearby Add")
    }
} 