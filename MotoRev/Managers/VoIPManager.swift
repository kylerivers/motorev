import Foundation
import CallKit
import AVFoundation
import Combine

final class VoIPManager: NSObject, ObservableObject {
    static let shared = VoIPManager()
    @Published var isActiveCall = false
    @Published var autoReconnect = true
    private let provider: CXProvider
    private let callController = CXCallController()
    private let audioSession = AVAudioSession.sharedInstance()
    
    private override init() {
        let config = CXProviderConfiguration()
        config.maximumCallsPerCallGroup = 1
        config.supportsVideo = false
        config.iconTemplateImageData = nil
        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: .main)
    }
    
    func connect() {
        let uuid = UUID()
        let action = CXStartCallAction(call: uuid, handle: CXHandle(type: .generic, value: "Group Intercom"))
        let transaction = CXTransaction(action: action)
        callController.request(transaction) { error in
            if let error = error { print("Call start error: \(error)") }
        }
    }
    
    func disconnect() {
        guard let call = callController.callObserver.calls.first else { return }
        let action = CXEndCallAction(call: call.uuid)
        let tx = CXTransaction(action: action)
        callController.request(tx) { error in
            if let error = error { print("Call end error: \(error)") }
        }
    }
}

extension VoIPManager: CXProviderDelegate {
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP, .defaultToSpeaker])
            try audioSession.setActive(true)
            isActiveCall = true
        } catch {
            print("Audio session error: \(error)")
        }
        provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        do { try audioSession.setActive(false) } catch {}
        isActiveCall = false
        action.fulfill()
    }
    
    func providerDidReset(_ provider: CXProvider) {
        isActiveCall = false
        if autoReconnect {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.connect()
            }
        }
    }
} 