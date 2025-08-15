import SwiftUI
import AVFoundation

struct GroupCommunicationView: View {
    @EnvironmentObject var nowPlayingManager: NowPlayingManager
    @EnvironmentObject var webRTCManager: WebRTCManager
    @EnvironmentObject var groupRideManager: GroupRideManager
    @EnvironmentObject var networkManager: NetworkManager
    
    @State private var selectedTab = 0
    @State private var isRecording = false
    @State private var isMuted = false
    @State private var isVoiceChatActive = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                Picker("Communication Mode", selection: $selectedTab) {
                    Text("Music").tag(0)
                    Text("Voice Chat").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    // Music Tab
                    musicControlsView
                        .tag(0)
                    
                    // Voice Chat Tab
                    voiceChatView
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
        }
        .navigationTitle("Communicate")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Music Controls View
    private var musicControlsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Now Playing Section
                if let currentTitle = nowPlayingManager.currentTitle,
                   let currentArtist = nowPlayingManager.currentArtist {
                    VStack(spacing: 16) {
                        Text("Now Playing")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // Album Art Placeholder
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            )
                            .frame(width: 200, height: 200)
                            .cornerRadius(12)
                        
                        // Track Info
                        VStack(spacing: 4) {
                            Text(currentTitle)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                            
                            Text(currentArtist)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Playback Controls
                        HStack(spacing: 30) {
                            Button(action: previousTrack) {
                                Image(systemName: "backward.fill")
                                    .font(.title)
                                    .foregroundColor(.blue)
                            }
                            
                            Button(action: nowPlayingManager.playPause) {
                                Image(systemName: nowPlayingManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.blue)
                            }
                            
                            Button(action: nextTrack) {
                                Image(systemName: "forward.fill")
                                    .font(.title)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                } else {
                    // No music playing
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.house")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Music Playing")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Open your music app to control playback here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Open Music App") {
                            if let url = URL(string: "music://") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
                
                Spacer(minLength: 100)
            }
        }
    }
    
    // MARK: - Voice Chat View
    private var voiceChatView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Connection Status
                HStack {
                    Circle()
                        .fill(isVoiceChatActive ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(isVoiceChatActive ? "Connected" : "Disconnected")
                        .font(.subheadline)
                        .foregroundColor(isVoiceChatActive ? .green : .red)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Voice Chat Controls
                VStack(spacing: 24) {
                    // Main Voice Button
                    Button(action: toggleVoiceChat) {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(isVoiceChatActive ? Color.red : Color.blue)
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: isVoiceChatActive ? "phone.down.fill" : "phone.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }
                            
                            Text(isVoiceChatActive ? "End Call" : "Start Voice Chat")
                                .font(.headline)
                                .foregroundColor(isVoiceChatActive ? .red : .blue)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Audio Controls
                    if isVoiceChatActive {
                        HStack(spacing: 40) {
                            // Mute Button
                            Button(action: toggleMute) {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(isMuted ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                                            .frame(width: 60, height: 60)
                                        
                                        Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(isMuted ? .red : .blue)
                                    }
                                    
                                    Text(isMuted ? "Unmute" : "Mute")
                                        .font(.caption)
                                        .foregroundColor(isMuted ? .red : .blue)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Speaker Button
                            Button(action: toggleSpeaker) {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.2))
                                            .frame(width: 60, height: 60)
                                        
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Text("Speaker")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.top)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Connected Users (if in voice chat)
                if isVoiceChatActive {
                    connectedUsersView
                }
                
                Spacer(minLength: 100)
            }
        }
    }
    
    // MARK: - Connected Users View
    private var connectedUsersView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Users")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVStack(spacing: 8) {
                ForEach(groupRideManager.groupMembers, id: \.id) { member in
                    HStack {
                        AsyncImage(url: URL(string: member.profilePictureUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                )
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.username)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Connected")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        // Audio indicator
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Actions
    private func toggleVoiceChat() {
        isVoiceChatActive.toggle()
        
        if isVoiceChatActive {
            // Start voice chat
            webRTCManager.connect()
        } else {
            // End voice chat
            webRTCManager.disconnect()
            isMuted = false
        }
    }
    
    private func toggleMute() {
        isMuted.toggle()
        webRTCManager.toggleMute()
    }
    
    private func toggleSpeaker() {
        // Toggle speaker/earpiece - placeholder implementation
        print("Speaker toggle - feature coming soon")
    }
    
    private func previousTrack() {
        // Previous track - placeholder implementation
        print("Previous track - feature coming soon")
    }
    
    private func nextTrack() {
        // Next track - placeholder implementation
        print("Next track - feature coming soon")
    }
}

#Preview {
    GroupCommunicationView()
        .environmentObject(NowPlayingManager.shared)
        .environmentObject(WebRTCManager.shared)
        .environmentObject(GroupRideManager.shared)
        .environmentObject(NetworkManager.shared)
}