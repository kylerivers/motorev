import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var premium: PremiumManager
    @Environment(\.dismiss) var dismiss
    @StateObject var sub = SubscriptionManager.shared
    
    var body: some View {
        VStack(spacing: 24) {
            Text("MotoRev Pro")
                .font(.largeTitle).bold()
            Text("Unlock Crash Recorder, AI Ride Assistant, Voice Commands, and Wind Chill Gear Suggestions.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            VStack(alignment: .leading, spacing: 12) {
                Label("Crash Detection & Emergency Recorder", systemImage: "shield.lefthalf.fill")
                Label("AI Ride Assistant", systemImage: "brain.head.profile")
                Label("Voice Commands", systemImage: "mic.fill")
                Label("Wind Chill + Gear", systemImage: "wind")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            if #available(iOS 15.0, *) {
                if sub.products.isEmpty {
                    ProgressView().task { await sub.loadProducts() }
                } else {
                    ForEach(sub.products, id: \.id) { product in
                        Button("Subscribe: \(product.displayName) - \(product.displayPrice)") {
                            Task { await sub.purchase(product) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                if let err = sub.lastError { Text(err).foregroundColor(.red) }
            } else {
                Button("Upgrade $3.47/mo or $20/yr") {
                    premium.isPremium = true
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            Button("Not now") { dismiss() }
                .foregroundColor(.secondary)
        }
        .padding()
    }
} 