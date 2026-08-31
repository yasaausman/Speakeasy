import SwiftUI

/// The signature element: a warm coral orb that gently breathes while idle and
/// turns to a live "listening" state. It's the invitation to speak.
struct VoiceOrb: View {
    var isListening: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    private var tint: Color { isListening ? Color.cool(0xE0454A, 0xF06A6F) : Theme.primary }
    private var tintDeep: Color { isListening ? Color.cool(0xC5383D, 0xE0555A) : Theme.primaryDeep }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: 236, height: 236)
                .blur(radius: 14)
                .scaleEffect(breathe && !reduceMotion ? 1.06 : 0.96)
            Circle()
                .fill(tint.opacity(0.24))
                .frame(width: 176, height: 176)
                .blur(radius: 6)

            Circle()
                .fill(
                    LinearGradient(colors: [tint, tintDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 136, height: 136)
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: tint.opacity(0.5), radius: 26, x: 0, y: 12)

            Image(systemName: isListening ? "waveform" : "mic.fill")
                .font(.system(size: 46, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .symbolEffect(.variableColor.iterative, isActive: isListening)
        }
        .scaleEffect(breathe && !reduceMotion ? 1.03 : 1.0)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 2.6).repeatForever(autoreverses: true),
            value: breathe
        )
        .onAppear { breathe = true }
        .accessibilityLabel(isListening ? "Listening" : "Tap and hold to speak")
    }
}
