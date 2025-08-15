import SwiftUI

struct GroupCommunicationView: View {
    @EnvironmentObject var nowPlayingManager: NowPlayingManager
    @EnvironmentObject var webRTCManager: WebRTCManager
    @EnvironmentObject var groupRideManager: GroupRideManager
    @EnvironmentObject var networkManager: NetworkManager
    @State private var selectedTab: CommunicationTab = .music
    
    enum CommunicationTab: String, CaseIterable {
        case music = "Music"
        case voice = "Voice Chat"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selection
                Picker("", selection: $selectedTab) {
                    ForEach(CommunicationTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Tab content
                TabView(selection: $selectedTab) {
                    SharedMusicView()
                        .environmentObject(nowPlayingManager)
                        .environmentObject(groupRideManager)
                        .tag(CommunicationTab.music)
                    
                    GroupVoiceChatView()
                        .environmentObject(webRTCManager)
                        .environmentObject(groupRideManager)
                        .environmentObject(networkManager)
                        .tag(CommunicationTab.voice)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Group Communication")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    GroupCommunicationView()
        .environmentObject(NowPlayingManager.shared)
        .environmentObject(WebRTCManager.shared)
        .environmentObject(GroupRideManager.shared)
        .environmentObject(NetworkManager.shared)
}
