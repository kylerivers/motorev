import SwiftUI
import Combine

struct GroupVoiceChatView: View {
    @EnvironmentObject var webRTC: WebRTCManager
    @EnvironmentObject var groupRide: GroupRideManager
    @EnvironmentObject var networkManager: NetworkManager
    @Environment(\.dismiss) private var dismiss
    @State private var isMuted = false
    @State private var connectedUsers: [ChatUser] = []
    @State private var isConnecting = false
    @State private var connectionError: String?
    @State private var chatMessage = ""
    @State private var messages: [ChatMessage] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with connection status
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(webRTC.isConnected ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        Text(webRTC.isConnected ? "Connected" : "Disconnected")
                            .font(.headline)
                            .foregroundColor(webRTC.isConnected ? .green : .red)
                        Spacer()
                        Text("\(connectedUsers.count) users")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let error = connectionError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Connected users grid
                if !connectedUsers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(connectedUsers) { user in
                                VStack {
                                    ZStack {
                                        Circle()
                                            .fill(user.isTalking ? Color.green : Color.gray)
                                            .frame(width: 60, height: 60)
                                        
                                        Image(systemName: user.isMuted ? "mic.slash.fill" : "mic.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                    }
                                    Text(user.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 100)
                }
                
                // Text chat area
                VStack(alignment: .leading, spacing: 0) {
                    Text("Chat")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(messages) { message in
                                    HStack {
                                        Text("\(message.username):")
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                        Text(message.text)
                                        Spacer()
                                        Text(message.timestamp, style: .time)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal)
                                    .id(message.id)
                                }
                            }
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let lastMessage = messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    
                    // Message input
                    HStack {
                        TextField("Type a message...", text: $chatMessage)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Send") {
                            sendMessage()
                        }
                        .disabled(chatMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                }
                .background(Color(.systemBackground))
                
                Spacer()
                
                // Voice controls
                HStack(spacing: 24) {
                    // Mute button
                    Button(action: { toggleMute() }) {
                        VStack {
                            Image(systemName: isMuted ? "mic.slash.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(isMuted ? .red : .green)
                            Text(isMuted ? "Unmute" : "Mute")
                                .font(.caption)
                        }
                    }
                    
                    // Disconnect button
                    Button(action: { disconnectFromChat() }) {
                        VStack {
                            Image(systemName: "phone.down.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                            Text("Leave")
                                .font(.caption)
                        }
                    }
                    
                    // Settings
                    Button(action: { /* Settings */ }) {
                        VStack {
                            Image(systemName: "gearshape.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("Settings")
                                .font(.caption)
                        }
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Group Voice Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            connectToGroupChat()
        }
        .onDisappear {
            disconnectFromChat()
        }
    }
    
    private func connectToGroupChat() {
        guard !isConnecting else { return }
        isConnecting = true
        connectionError = nil
        
        // Connect via WebRTC
        webRTC.connect()
        
        // Load existing chat messages
        loadChatHistory()
        
        // Simulate some connected users (replace with real data)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.connectedUsers = [
                ChatUser(id: "1", name: "Alex", isTalking: false, isMuted: false),
                ChatUser(id: "2", name: "Sarah", isTalking: true, isMuted: false),
                ChatUser(id: "3", name: "Mike", isTalking: false, isMuted: true)
            ]
            self.isConnecting = false
        }
    }
    
    private func disconnectFromChat() {
        webRTC.disconnect()
        connectedUsers.removeAll()
    }
    
    private func toggleMute() {
        isMuted.toggle()
        webRTC.setMuted(isMuted)
    }
    
    private func sendMessage() {
        let trimmed = chatMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let message = ChatMessage(
            id: UUID().uuidString,
            username: "You", // Replace with actual username
            text: trimmed,
            timestamp: Date()
        )
        
        messages.append(message)
        chatMessage = ""
        
        // Send to group ride manager
        groupRide.sendMessage(trimmed) { result in
            // Handle result if needed
        }
    }
    
    private func loadChatHistory() {
        // Simulate loading chat history
        messages = [
            ChatMessage(id: "1", username: "Alex", text: "Ready to ride!", timestamp: Date().addingTimeInterval(-300)),
            ChatMessage(id: "2", username: "Sarah", text: "See you at the meetup point", timestamp: Date().addingTimeInterval(-240))
        ]
    }
}

struct ChatUser: Identifiable {
    let id: String
    let name: String
    var isTalking: Bool
    var isMuted: Bool
}

struct ChatMessage: Identifiable {
    let id: String
    let username: String
    let text: String
    let timestamp: Date
}

#Preview {
    GroupVoiceChatView()
        .environmentObject(WebRTCManager.shared)
        .environmentObject(GroupRideManager.shared)
        .environmentObject(NetworkManager.shared)
}
