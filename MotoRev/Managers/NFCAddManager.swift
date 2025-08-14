import Foundation
import Combine

#if canImport(CoreNFC)
import CoreNFC
#endif

final class NFCAddManager: NSObject, ObservableObject {
    static let shared = NFCAddManager()

    @Published var lastScannedUsername: String?

    private override init() { }

    #if canImport(CoreNFC)
    private var tagWriteSession: NFCTagReaderSession?
    private var pendingUsernameToWrite: String?
    #endif

    func startScanning() {
        #if canImport(CoreNFC)
        if NFCNDEFReaderSession.readingAvailable {
            let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
            session.alertMessage = "Hold your iPhone near the NFC tag"
            session.begin()
            return
        }
        #endif
        // Fallback for simulator or devices without NFC: simulate a scan
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.lastScannedUsername = "demo_user"
        }
    }

    func writeUsername(_ username: String) {
        let sanitized = username.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "@", with: "")
        guard !sanitized.isEmpty else { return }

        #if canImport(CoreNFC)
        pendingUsernameToWrite = sanitized
        if let session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693, .iso18092], delegate: self, queue: nil) {
            session.alertMessage = "Hold your iPhone near the NFC tag to write your username"
            session.begin()
            tagWriteSession = session
        } else {
            print("[NFC] Failed to create NFCTagReaderSession")
        }
        #else
        // Simulator / devices without NFC: pretend success
        DispatchQueue.main.async { [weak self] in
            self?.lastScannedUsername = sanitized
            print("[NFC] Simulated write of username: \(sanitized)")
        }
        #endif
    }
}

#if canImport(CoreNFC)
extension NFCAddManager: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // No-op; session auto invalidates after first read
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        for message in messages {
            for record in message.records {
                if let username = decodeUsername(from: record) {
                    DispatchQueue.main.async {
                        self.lastScannedUsername = username
                    }
                    return
                }
            }
        }
    }

    private func decodeUsername(from record: NFCNDEFPayload) -> String? {
        // Prefer well-known text records: TNF = .nfcWellKnown, type = "T"
        if record.typeNameFormat == .nfcWellKnown, let typeString = String(data: record.type, encoding: .utf8), typeString == "T" {
            // Text record: first byte is status (encoding/lang), then language code, then text
            guard let text = String(data: record.payload.dropFirst(3), encoding: .utf8) else { return nil }
            return sanitizeUsername(text)
        }
        // Fallback: try to parse UTF-8 payload as plain string
        if let text = String(data: record.payload, encoding: .utf8) {
            return sanitizeUsername(text)
        }
        return nil
    }

    private func sanitizeUsername(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("@") { s.removeFirst() }
        return s
    }
}
#endif

#if canImport(CoreNFC)
extension NFCAddManager: NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) { }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        tagWriteSession = nil
        pendingUsernameToWrite = nil
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let pending = pendingUsernameToWrite else {
            session.invalidate(errorMessage: "Nothing to write")
            return
        }

        guard let firstTag = tags.first else {
            session.invalidate(errorMessage: "No tag detected")
            return
        }

        // If multiple tags detected, ask the user to present only one
        if tags.count > 1 {
            session.alertMessage = "More than one tag detected, please present only one tag."
            session.restartPolling()
            return
        }

        session.connect(to: firstTag) { [weak self] error in
            if let error = error {
                session.invalidate(errorMessage: "Failed to connect to tag: \(error.localizedDescription)")
                return
            }

            let ndefTag: NFCNDEFTag
            switch firstTag {
            case .miFare(let tag): ndefTag = tag
            case .iso7816(let tag): ndefTag = tag
            case .iso15693(let tag): ndefTag = tag
            case .feliCa(let tag): ndefTag = tag
            @unknown default:
                session.invalidate(errorMessage: "Unsupported tag type")
                return
            }

            ndefTag.queryNDEFStatus { status, capacity, statusError in
                if let statusError = statusError {
                    session.invalidate(errorMessage: "Failed to query tag: \(statusError.localizedDescription)")
                    return
                }

                guard status != .notSupported else {
                    session.invalidate(errorMessage: "Tag does not support NDEF")
                    return
                }

                // Build a well-known Text record with language code "en"
                guard let message = NFCAddManager.buildUsernameMessage(username: pending) else {
                    session.invalidate(errorMessage: "Failed to build NDEF message")
                    return
                }

                // Ensure capacity is sufficient
                let msgSize = message.length
                guard capacity >= msgSize else {
                    session.invalidate(errorMessage: "Tag capacity too small (need \(msgSize) bytes)")
                    return
                }

                guard status == .readWrite else {
                    session.invalidate(errorMessage: "Tag is read-only")
                    return
                }

                ndefTag.writeNDEF(message) { writeError in
                    if let writeError = writeError {
                        session.invalidate(errorMessage: "Write failed: \(writeError.localizedDescription)")
                        return
                    }

                    DispatchQueue.main.async {
                        self?.lastScannedUsername = pending
                    }
                    session.alertMessage = "Username written successfully"
                    session.invalidate()
                }
            }
        }
    }

    private static func buildUsernameMessage(username: String) -> NFCNDEFMessage? {
        let lang = "en"
        guard let langData = lang.data(using: .utf8), let textData = username.data(using: .utf8) else { return nil }
        var payload = Data()
        payload.append(UInt8(langData.count)) // status byte: UTF-8 (bit7=0) + language code length
        payload.append(langData)
        payload.append(textData)
        let record = NFCNDEFPayload(format: .nfcWellKnown, type: "T".data(using: .utf8)!, identifier: Data(), payload: payload)
        return NFCNDEFMessage(records: [record])
    }
}
#endif 