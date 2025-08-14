import Foundation
import Speech
import Combine

final class VoiceAssistantManager: NSObject, ObservableObject {
    static let shared = VoiceAssistantManager()
    
    @Published var isListening: Bool = false
    @Published var lastCommand: String = ""
    
    enum Command: String {
        case startRide = "start ride"
        case pauseTracking = "pause tracking"
        case resumeTracking = "resume tracking"
        case stopRide = "stop ride"
        case checkWeather = "check weather ahead"
    }
    
    let commandPublisher = PassthroughSubject<Command, Never>()
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private override init() { super.init() }
    
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async { completion(status == .authorized) }
        }
    }
    
    func startListening() {
        guard !isListening else { return }
        if PremiumManager.shared.isPremium == false {
            print("Voice Assistant is Pro feature. Prompt paywall.")
            return
        }
        isListening = true
        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true
        
        let node = audioEngine.inputNode
        let recordingFormat = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        
        do {
            try audioEngine.start()
        } catch {
            isListening = false
            return
        }
        
        guard let recognizer, let request else { return }
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let text = result?.bestTranscription.formattedString.lowercased() {
                self.lastCommand = text
                self.detectCommand(in: text)
            }
            if error != nil || (result?.isFinal ?? false) {
                self.stopListening()
            }
        }
    }
    
    func stopListening() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        isListening = false
    }
    
    private func detectCommand(in text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.contains(Command.startRide.rawValue) {
            commandPublisher.send(.startRide)
        } else if normalized.contains(Command.pauseTracking.rawValue) {
            commandPublisher.send(.pauseTracking)
        } else if normalized.contains(Command.resumeTracking.rawValue) {
            commandPublisher.send(.resumeTracking)
        } else if normalized.contains(Command.stopRide.rawValue) {
            commandPublisher.send(.stopRide)
        } else if normalized.contains(Command.checkWeather.rawValue) {
            commandPublisher.send(.checkWeather)
        }
    }
} 