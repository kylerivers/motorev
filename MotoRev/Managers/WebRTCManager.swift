import Foundation
import Combine

final class WebRTCManager: ObservableObject {
    static let shared = WebRTCManager()
    @Published var isConnected: Bool = false
    @Published var roomId: String?
    @Published var participants: [String] = []
    @Published var isMuted: Bool = false
    
    private let networkManager = NetworkManager.shared
    
    private init() {}
    
    func connect(to roomId: String) {
        self.roomId = roomId
        
        // Connect to voice chat room via backend
        let request = ["roomId": roomId]
        makeAuthenticatedRequest(endpoint: "/api/voice/join", method: "POST", body: request) { (result: Result<MessageResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.isConnected = true
                    print("[WebRTC] Connected to room: \(roomId)")
                    
                    #if canImport(WebRTC)
                    // TODO: Initialize RTCPeerConnection, audio track, and signaling here
                    #endif
                    
                case .failure(let error):
                    print("[WebRTC] Failed to connect to room: \(error)")
                }
            }
        }
    }
    
    func connectToGroupRide(groupId: String) {
        connect(to: "group-\(groupId)")
    }
    
    func disconnect() {
        guard let roomId = roomId else { return }
        
        let request = ["roomId": roomId]
        makeAuthenticatedRequest(endpoint: "/api/voice/leave", method: "POST", body: request) { (result: Result<MessageResponse, Error>) in
            #if canImport(WebRTC)
            // TODO: Close peer connection and cleanup
            #endif
            
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("[WebRTC] Disconnected from room: \(roomId)")
                case .failure(let error):
                    print("[WebRTC] Failed to disconnect properly: \(error)")
                }
                
                // Always disconnect locally regardless of backend response
                self.roomId = nil
                self.isConnected = false
                self.participants = []
            }
        }
    }
    
    func toggleMute() {
        isMuted.toggle()
        setMuted(isMuted)
    }
    
    func setMuted(_ muted: Bool) {
        isMuted = muted
        
        let request = ["muted": muted]
        makeAuthenticatedRequest(endpoint: "/api/voice/mute", method: "POST", body: request) { (result: Result<MessageResponse, Error>) in
            switch result {
            case .success:
                print("[WebRTC] Mute state updated successfully")
            case .failure(let error):
                print("[WebRTC] Failed to update mute state: \(error)")
            }
        }
        
        #if canImport(WebRTC)
        // TODO: Set audio track enabled/disabled
        #endif
        print("[WebRTC] Mute state changed to: \(muted)")
    }
    
    func bindToCallKit() {
        // Placeholder: setup audio session categories if needed with VoIPManager
    }
    
    func unbindFromCallKit() {
        // Placeholder: teardown audio session resources
    }
    
    func connect() {
        // Default connection without room ID
        connect(to: "default-room")
    }
}

// MARK: - WebRTCManager Network Extension
extension WebRTCManager {
    private func makeAuthenticatedRequest<T: Codable, U: Codable>(
        endpoint: String,
        method: String,
        body: T? = nil,
        completion: @escaping (Result<U, Error>) -> Void
    ) where U: Sendable {
        guard let token = networkManager.authToken else {
            completion(.failure(NSError(domain: "WebRTCManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authentication token"])))
            return
        }

        // Build URL from NetworkManager baseURL, avoiding duplicate "/api"
        let base = networkManager.baseURL // e.g. https://.../api
        let trimmedEndpoint = endpoint.hasPrefix("/api/") ? String(endpoint.dropFirst(5)) : endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = base.hasSuffix("/") ? base + trimmedEndpoint : base + "/" + trimmedEndpoint
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "WebRTCManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Only attach body for non-GET methods
        if method.uppercased() != "GET", let body = body {
            do {
                let encoder = JSONEncoder()
                request.httpBody = try encoder.encode(body)
            } catch {
                completion(.failure(error))
                return
            }
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let http = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "WebRTCManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            guard (200..<300).contains(http.statusCode), let data = data else {
                completion(.failure(NSError(domain: "WebRTCManager", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])))
                return
            }

            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(U.self, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func makeAuthenticatedRequest<U: Codable>(
        endpoint: String,
        method: String,
        completion: @escaping (Result<U, Error>) -> Void
    ) where U: Sendable {
        makeAuthenticatedRequest(endpoint: endpoint, method: method, body: Optional<EmptyBody>.none, completion: completion)
    }
} 