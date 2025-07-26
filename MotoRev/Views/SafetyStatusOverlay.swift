import SwiftUI
import UIKit

struct SafetyStatusOverlay: View {
    @EnvironmentObject var safetyManager: SafetyManager
    @EnvironmentObject var watchManager: WatchManager
    @State private var showingEmergencyAlert = false
    @State private var emergencyCountdown = 0
    
    var body: some View {
        VStack {
            HStack {
                // Safety status indicator
                HStack(spacing: 6) {
                    Image(systemName: safetyIcon)
                        .font(.caption)
                        .foregroundColor(safetyColor)
                    
                    Text(safetyText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(safetyColor)
                    
                    if safetyManager.isRiding {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color.red, lineWidth: 2)
                                    .scaleEffect(1.5)
                                    .opacity(0.7)
                                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: false), value: safetyManager.isRiding)
                            )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            Capsule()
                                .stroke(safetyColor, lineWidth: 1)
                        )
                )
                
                Spacer()
                
                // Watch connection status
                if watchManager.isWatchConnected {
                    HStack(spacing: 4) {
                        Image(systemName: "applewatch")
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Text("\(Int(watchManager.watchBatteryLevel * 100))%")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                    )
                }
            }
            
            Spacer()
        }
        .padding()
        .onReceive(NotificationCenter.default.publisher(for: .emergencyDetected)) { _ in
            showingEmergencyAlert = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .emergencyCountdownStarted)) { notification in
            if let countdown = notification.userInfo?["countdown"] as? Int {
                emergencyCountdown = countdown
            }
        }
        .alert("Emergency Detected", isPresented: $showingEmergencyAlert) {
            Button("I'm OK", role: .cancel) {
                safetyManager.cancelEmergencyAlert()
            }
            Button("Call 911", role: .destructive) {
                // Call emergency services using the public API
                if let phoneURL = URL(string: "tel://911") {
                    UIApplication.shared.open(phoneURL)
                }
            }
        } message: {
            Text("Potential crash detected. Emergency services will be contacted in \(emergencyCountdown) seconds unless you respond.")
        }
    }
    
    private var safetyIcon: String {
        switch safetyManager.safetyStatus {
        case .safe:
            return "shield.checkered"
        case .warning:
            return "exclamationmark.triangle"
        case .emergency:
            return "exclamationmark.octagon.fill"
        case .crashDetected:
            return "exclamationmark.circle.fill"
        }
    }
    
    private var safetyColor: Color {
        switch safetyManager.safetyStatus {
        case .safe:
            return .green
        case .warning:
            return .yellow
        case .emergency, .crashDetected:
            return .red
        }
    }
    
    private var safetyText: String {
        switch safetyManager.safetyStatus {
        case .safe:
            return safetyManager.isRiding ? "Riding Safe" : "Safe"
        case .warning:
            return "Caution"
        case .emergency:
            return "Emergency"
        case .crashDetected:
            return "Crash Alert"
        }
    }
}

#Preview {
    SafetyStatusOverlay()
        .environmentObject(SafetyManager.shared)
        .environmentObject(WatchManager.shared)
} 