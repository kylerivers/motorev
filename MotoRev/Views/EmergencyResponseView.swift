import SwiftUI
import AVFoundation

struct EmergencyResponseView: View {
    @ObservedObject var crashDetectionManager = CrashDetectionManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var pulseScale: CGFloat = 1.0
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Critical background overlay
            Color.red.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Emergency Icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .scaleEffect(pulseScale)
                    .animation(
                        Animation.easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true),
                        value: pulseScale
                    )
                
                // Title
                Text("CRASH DETECTED")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Crash details
                if let crashEvent = crashDetectionManager.lastCrashEvent {
                    VStack(spacing: 8) {
                        Text("Type: \(crashEvent.type.description)")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("Confidence: \(Int(crashEvent.probability * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Countdown Display
                VStack(spacing: 16) {
                    Text("Emergency Response in")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    // Large countdown number
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 8)
                            .frame(width: 200, height: 200)
                        
                        Circle()
                            .trim(from: 0.0, to: CGFloat(1.0 - Double(crashDetectionManager.emergencyCountdown) / 45.0))
                            .stroke(
                                Color.white,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 200, height: 200)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1.0), value: crashDetectionManager.emergencyCountdown)
                        
                        Text("\(crashDetectionManager.emergencyCountdown)")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Text("seconds")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Action Instructions
                VStack(spacing: 12) {
                    Text("Are you okay?")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Tap the button below if you're safe")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                
                // Cancel Emergency Button
                Button(action: {
                    crashDetectionManager.confirmImOkay()
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                    impactFeedback.impactOccurred()
                }) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .font(.title2)
                        Text("I'M OKAY - CANCEL")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.red)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 40)
                    .background(Color.white)
                    .cornerRadius(25)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
                
                Spacer()
                
                // Emergency services info
                VStack(spacing: 8) {
                    Text("If no response:")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("• Emergency services will be called automatically")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("• Your emergency contacts will be notified")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("• Your location will be shared")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(.horizontal, 30)
        }
        .onAppear {
            startAnimations()
        }
        .preferredColorScheme(.dark) // Force dark mode for emergency
    }
    
    private func startAnimations() {
        pulseScale = 1.2
        isAnimating = true
    }
}

// MARK: - Emergency Alert Overlay
struct EmergencyAlertOverlay: View {
    @ObservedObject var crashDetectionManager = CrashDetectionManager.shared
    
    var body: some View {
        ZStack {
            if crashDetectionManager.crashDetected {
                EmergencyResponseView()
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(1000) // Ensure it appears above everything
            }
        }
        .animation(.easeInOut(duration: 0.5), value: crashDetectionManager.crashDetected)
    }
}

#Preview {
    EmergencyResponseView()
} 