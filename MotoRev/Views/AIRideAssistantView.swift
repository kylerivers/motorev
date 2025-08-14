import SwiftUI

struct AIRideAssistantView: View {
    @EnvironmentObject var ai: AIRideAssistantManager
    @EnvironmentObject var premium: PremiumManager
    @State private var showingGear = false
    @State private var showingWindChill = false
    @State private var showingVoiceHelp = false
    
    var body: some View {
        Group {
            if premium.isPremium {
                List {
                    Section(header: Text("Suggestions")) {
                        if ai.suggestions.isEmpty {
                            Text("No suggestions yet. Ride a bit and check back.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(ai.suggestions, id: \.self) { s in
                                Text(s)
                            }
                        }
                    }
                }
                .onAppear { ai.startAnalyzing() }
                .onDisappear { ai.stopAnalyzing() }
            } else {
                VStack(spacing: 16) {
                    PaywallView()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Premium Previews").font(.headline)
                        HStack(spacing: 12) {
                            PreviewCard(title: "Wind Chill", subtitle: "Dress right for the ride", action: { showingWindChill = true })
                            PreviewCard(title: "Gear", subtitle: "Smart outfit picks", action: { showingGear = true })
                            PreviewCard(title: "Voice", subtitle: "Hands-free control", action: { showingVoiceHelp = true })
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("AI Ride Assistant")
        .sheet(isPresented: $showingGear) { GearSuggestionPreview() }
        .sheet(isPresented: $showingWindChill) { WindChillPreview() }
        .sheet(isPresented: $showingVoiceHelp) { VoiceAssistantHelpView() }
    }
} 

private struct PreviewCard: View {
    let title: String
    let subtitle: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline).bold()
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GearSuggestionPreview: View {
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Example Gear Suggestions")
                Text("• Mesh jacket + base layer")
                Text("• Vented gloves")
                Text("• Light rain shell in tail bag")
                Spacer()
            }
            .padding()
            .navigationTitle("Gear Preview")
        }
    }
}

struct WindChillPreview: View {
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Wind Chill Example")
                Text("Ambient: 55°F, Speed: 55 mph → Feels like: 44°F")
                Text("Tip: Add a windproof mid-layer")
                Spacer()
            }
            .padding()
            .navigationTitle("Wind Chill")
        }
    }
}

struct VoiceAssistantHelpView: View {
    @EnvironmentObject var voiceAssistant: VoiceAssistantManager
    @EnvironmentObject var premium: PremiumManager
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Voice Control")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Voice Assistant")
                                .font(.headline)
                            Text(voiceAssistant.isListening ? "Listening..." : "Tap to activate voice control")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            if premium.isPremium {
                                if voiceAssistant.isListening {
                                    voiceAssistant.stopListening()
                                } else {
                                    voiceAssistant.startListening()
                                }
                            } else {
                                showPaywall = true
                            }
                        }) {
                            Image(systemName: voiceAssistant.isListening ? "mic.fill" : "mic")
                                .font(.title2)
                                .foregroundColor(voiceAssistant.isListening ? .red : .blue)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if !voiceAssistant.lastCommand.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Command:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(voiceAssistant.lastCommand)
                                .font(.subheadline)
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                
                Section(header: Text("Available Commands")) {
                    VoiceCommandRow(command: "start my ride", description: "Begin ride tracking")
                    VoiceCommandRow(command: "pause tracking", description: "Pause current ride")
                    VoiceCommandRow(command: "resume tracking", description: "Resume paused ride")
                    VoiceCommandRow(command: "stop ride", description: "End current ride")
                    VoiceCommandRow(command: "check weather", description: "Get weather update")
                }
                
                if !premium.isPremium {
                    Section {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.orange)
                                Text("Premium Feature")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                            
                            Text("Voice Assistant requires MotoRev Pro. Upgrade to unlock hands-free voice control while riding.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button("Upgrade to Pro") {
                                showPaywall = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Voice Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

struct VoiceCommandRow: View {
    let command: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\"Hey MotoRev, \(command)\"")
                .font(.subheadline)
                .fontWeight(.medium)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}