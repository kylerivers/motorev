import Foundation
import MediaPlayer
import Combine

final class NowPlayingManager: ObservableObject {
    static let shared = NowPlayingManager()
    @Published var currentTitle: String? = nil
    @Published var currentArtist: String? = nil
    @Published var isPlaying: Bool = false
    @Published var groupSession: MusicSession? = nil
    @Published var isInGroupSession: Bool = false
    
    private let controller = MPMusicPlayerController.systemMusicPlayer
    private let networkManager = NetworkManager.shared
    
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleNowPlaying), name: .MPMusicPlayerControllerNowPlayingItemDidChange, object: controller)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePlayback), name: .MPMusicPlayerControllerPlaybackStateDidChange, object: controller)
        controller.beginGeneratingPlaybackNotifications()
        refresh()
    }
    
    deinit { controller.endGeneratingPlaybackNotifications() }
    
    func refresh() {
        currentTitle = controller.nowPlayingItem?.title
        currentArtist = controller.nowPlayingItem?.artist
        isPlaying = controller.playbackState == .playing
        
        // Share with group if in session and track changed
        if isInGroupSession, let title = currentTitle, let artist = currentArtist {
            shareCurrentTrackWithGroup(title: title, artist: artist)
        }
    }
    
    func playPause() {
        if isPlaying { controller.pause() } else { controller.play() }
        refresh()
    }
    
    func shareCurrentTrackWithGroup(title: String, artist: String) {
        guard let groupRideId = GroupRideManager.shared.currentGroupRide?.id else { return }
        
        let request = ShareMusicRequest(
            trackTitle: title,
            artist: artist,
            groupId: groupRideId
        )
        
        makeAuthenticatedRequest(endpoint: "/api/music/share", method: "POST", body: request) { (result: Result<MessageResponse, Error>) in
            switch result {
            case .success:
                print("[Music] Shared track with group: \(title) by \(artist)")
            case .failure(let error):
                print("[Music] Failed to share track: \(error)")
            }
        }
    }
    
    func joinGroupMusicSession(groupId: String) {
        makeAuthenticatedRequest(endpoint: "/api/music/session/\(groupId)", method: "GET") { (result: Result<MusicSessionResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self.groupSession = response.session
                    self.isInGroupSession = true
                    print("[Music] Joined group music session: \(groupId)")
                case .failure(let error):
                    print("[Music] Failed to join group session: \(error)")
                }
            }
        }
    }
    
    func leaveGroupMusicSession() {
        groupSession = nil
        isInGroupSession = false
    }
    
    @objc private func handleNowPlaying() { refresh() }
    @objc private func handlePlayback() { refresh() }
}

// MARK: - NowPlayingManager Network Extension
extension NowPlayingManager {
    private func makeAuthenticatedRequest<T: Codable, U: Codable>(
        endpoint: String,
        method: String,
        body: T? = nil,
        completion: @escaping (Result<U, Error>) -> Void
    ) where U: Sendable {
        guard let token = networkManager.authToken else {
            completion(.failure(NSError(domain: "NowPlayingManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authentication token"])))
            return
        }

        // Build URL from NetworkManager baseURL, avoiding duplicate "/api"
        let base = networkManager.baseURL // e.g. https://.../api
        let trimmedEndpoint = endpoint.hasPrefix("/api/") ? String(endpoint.dropFirst(5)) : endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = base.hasSuffix("/") ? base + trimmedEndpoint : base + "/" + trimmedEndpoint
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "NowPlayingManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"])))
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
                completion(.failure(NSError(domain: "NowPlayingManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            guard (200..<300).contains(http.statusCode), let data = data else {
                completion(.failure(NSError(domain: "NowPlayingManager", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])))
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