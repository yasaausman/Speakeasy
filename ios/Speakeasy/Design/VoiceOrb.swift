import SwiftUI

/// The signature element: a friendly sky-blue orb with a mascot face that gently
/// breathes and blinks while idle, and turns green while listening (amber on a
/// mic/speech error). It's the invitation to speak.
struct VoiceOrb: View {
    var isListening: Bool
    /// True when a listen attempt just failed (mic/speech couldn't start) — the
    /// orb goes amber to match the error banner.
    var hasError: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false
    @State private var blink = false

    private var tint: Color {
        if hasError { return Theme.warning }
        return isListening ? Theme.success : Theme.primary
    }
    private var tintDeep: Color {
        if hasError { return Theme.warning.opacity(0.8) }
        return isListening ? Theme.success.opacity(0.8) : Theme.primaryDeep
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 240, height: 240)
                .scaleEffect(breathe && !reduceMotion ? 1.08 : 0.92)
            Circle()
                .fill(tint.opacity(0.20))
                .frame(width: 180, height: 180)
                .scaleEffect(breathe && !reduceMotion ? 1.04 : 0.96)

            Circle()
                .fill(tint) // Solid playful color
                .frame(width: 140, height: 140)
                .shadow(color: tintDeep, radius: 0, x: 0, y: 8) // Hard shadow for 3D button effect
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 4)
                )

            // Mascot Face!
            VStack(spacing: 10) {
                HStack(spacing: 24) {
                    // Left eye
                    Capsule()
                        .fill(.white)
                        .frame(width: 16, height: isListening ? 26 : 20)
                        .scaleEffect(y: blink ? 0.1 : 1.0, anchor: .center)
                    // Right eye
                    Capsule()
                        .fill(.white)
                        .frame(width: 16, height: isListening ? 26 : 20)
                        .scaleEffect(y: blink ? 0.1 : 1.0, anchor: .center)
                }
                .padding(.top, isListening ? 0 : 4)

                // Mouth
                if isListening {
                    Circle()
                        .trim(from: 0.0, to: 0.5)
                        .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .fill(.white)
                        .frame(width: 24, height: 24) // Upturned open-mouth smile
                } else {
                    Capsule()
                        .fill(.white)
                        .frame(width: 32, height: 6)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isListening)
            .animation(.interactiveSpring(response: 0.15), value: blink)
        }
        .onReceive(Timer.publish(every: 4.2, on: .main, in: .common).autoconnect()) { _ in
            if !isListening {
                blink = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { blink = false }
            }
        }
        .scaleEffect(breathe && !reduceMotion ? 1.02 : 1.0)
        .animation(
            reduceMotion ? nil : .spring(response: 1.2, dampingFraction: 0.5, blendDuration: 1.0).repeatForever(autoreverses: true),
            value: breathe
        )
        .onAppear { breathe = true }
        .accessibilityLabel(isListening ? "Listening" : (hasError ? "Didn't catch that" : "Tap and hold to speak"))
    }
}
