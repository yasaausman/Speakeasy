import SwiftUI

/// A calm, text-forward explainer — doubles as accessibility-friendly onboarding.
struct AboutView: View {
    private let steps: [(String, String, String)] = [
        ("mic.fill", "Say what you need", "Speak or type in your language — book an appointment, ask a question, sort out a bill."),
        ("checkmark.bubble.fill", "Check it's right", "Speakeasy reads your request back in your language. Nothing is called until you say yes."),
        ("phone.connection.fill", "We make the call", "Speakeasy phones in English, navigates the menu, and talks to the person — you watch it happen live."),
        ("speaker.wave.2.fill", "Hear what happened", "You get the outcome and any confirmation number, spoken and written in your language, and saved."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                Text("Speakeasy makes the English phone calls you'd rather not — and tells you what happened, in your language.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Theme.ink)

                VStack(spacing: Theme.Space.s) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: Theme.Space.m) {
                            ZStack {
                                Circle().fill(Theme.primary.opacity(0.12)).frame(width: 48, height: 48)
                                Image(systemName: step.0).font(.title3).foregroundStyle(Theme.primary)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(step.1).font(.headline).foregroundStyle(Theme.ink)
                                Text(step.2).font(.subheadline).foregroundStyle(Theme.inkSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(Theme.Space.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .softCard(Theme.surface)
                    }
                }

                Label("Built for people with phone anxiety, limited English, or no time during business hours.",
                      systemImage: "heart.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
                    .padding(.top, Theme.Space.xs)
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.m)
        }
    }
}
