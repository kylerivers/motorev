import Foundation
import AVFoundation
import Combine

final class IntercomManager: ObservableObject {
    static let shared = IntercomManager()
    
    @Published var isConnected: Bool = false
    @Published var isMuted: Bool = false
    @Published var nowPlayingApp: String? = nil // e.g., Spotify/Apple Music
    
    private let audioSession = AVAudioSession.sharedInstance()
    
    private init() {}
    
    func connectGroupChannel() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP, .allowBluetoothA2DP, .defaultToSpeaker])
            try audioSession.setActive(true)
            isConnected = true
        } catch {
            isConnected = false
        }
    }
    
    func disconnect() {
        do { try audioSession.setActive(false) } catch {}
        isConnected = false
    }
    
    func toggleMute() { isMuted.toggle() }
    
    func setNowPlaying(appName: String?) { nowPlayingApp = appName }
} 