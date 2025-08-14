import SwiftUI
import AVFoundation

struct QRFriendView: View {
    @EnvironmentObject var socialManager: SocialManager
    @State private var isScanning = false
    @State private var scannedUsername: String?

    var body: some View {
        VStack(spacing: 24) {
            Text("Your QR Code")
                .font(.headline)
            // Placeholder image — would generate from username
            if let img = generateQRCode(from: socialManager.currentUser?.username ?? "") {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            }
            Button(isScanning ? "Stop Scanning" : "Scan QR") {
                isScanning.toggle()
            }
            if let scannedUsername {
                Text("Scanned: @\(scannedUsername)")
                Button("Add Friend") { socialManager.addFriend(byUsername: scannedUsername) }
            }
            if isScanning {
                QRScannerView(onDetect: { value in
                    self.scannedUsername = value
                    self.isScanning = false
                })
                .frame(height: 240)
            }
        }
        .padding()
        .navigationTitle("QR Friend")
    }
}

// QR helper
private func generateQRCode(from string: String) -> UIImage? {
    guard let data = string.data(using: .utf8) else { return nil }
    if let filter = CIFilter(name: "CIQRCodeGenerator") {
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage else { return nil }
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        return UIImage(ciImage: transformed)
    }
    return nil
}

struct QRScannerView: UIViewControllerRepresentable {
    let onDetect: (String) -> Void
    
    func makeUIViewController(context: Context) -> ScannerVC {
        ScannerVC(onDetect: onDetect)
    }
    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {}
}

final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let onDetect: (String) -> Void
    private let session = AVCaptureSession()
    
    init(onDetect: @escaping (String) -> Void) {
        self.onDetect = onDetect
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        let output = AVCaptureMetadataOutput()
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.layer.bounds
        view.layer.addSublayer(preview)
        session.startRunning()
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              obj.type == .qr,
              let value = obj.stringValue else { return }
        session.stopRunning()
        onDetect(value)
    }
} 