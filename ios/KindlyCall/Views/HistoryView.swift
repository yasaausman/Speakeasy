import SwiftUI

/// Past calls: outcomes, saved confirmation numbers, replayable narration.
struct HistoryView: View {
    @ObservedObject var store: AppStore
    var speak: (String, String) -> Void   // (text, languageCode)

    var body: some View {
        Group {
            if store.history.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: Theme.Space.s) {
                        ForEach(store.history) { call in
                            card(call)
                        }
                        Button(role: .destructive) { store.clearHistory() } label: {
                            Label("Clear history", systemImage: "trash")
                                .font(.subheadline.weight(.medium))
                        }
                        .tint(Theme.primaryDeep)
                        .padding(.top, Theme.Space.s)
                    }
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.vertical, Theme.Space.m)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.m) {
            ZStack {
                Circle().fill(Theme.primary.opacity(0.12)).frame(width: 96, height: 96)
                Image(systemName: "clock.arrow.circlepath").font(.system(size: 40)).foregroundStyle(Theme.primary)
            }
            Text("No calls yet").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            Text("Your finished calls — outcomes and confirmation numbers — will be saved here.")
                .font(.subheadline).foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func card(_ call: StoredCall) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack {
                Label(call.isComparison ? "Comparison" : "Call",
                      systemImage: call.isComparison ? "trophy.fill" : "phone.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(call.isComparison ? Theme.accent : Theme.primary)
                Spacer()
                Text(call.date, format: .dateTime.month().day().hour().minute())
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
            }

            Text(call.goal).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            Text(call.outcome).font(.footnote).foregroundStyle(Theme.inkSecondary)

            HStack(spacing: Theme.Space.s) {
                if !call.confirmations.isEmpty {
                    Text(call.confirmations.joined(separator: "  "))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.primaryDeep)
                        .padding(.vertical, 5).padding(.horizontal, 12)
                        .background(Capsule().fill(Theme.primary.opacity(0.12)))
                }
                Spacer()
                Button { speak(call.outcome, call.languageCode) } label: {
                    Label("Play", systemImage: "speaker.wave.2.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(Theme.surface)
    }
}
