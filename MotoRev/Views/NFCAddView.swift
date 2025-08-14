import SwiftUI

struct NFCAddView: View {
    @EnvironmentObject var nfc: NFCAddManager
    @EnvironmentObject var social: SocialManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Tap to scan NFC tag")
                .font(.headline)
            Button("Start Scan") { nfc.startScanning() }
                .buttonStyle(.borderedProminent)
            if let username = nfc.lastScannedUsername {
                Text("Scanned: @\(username)")
                Button("Add Friend") { social.addFriend(byUsername: username) }
            }
            Spacer()
        }
        .padding()
        .navigationTitle("NFC Add")
    }
} 