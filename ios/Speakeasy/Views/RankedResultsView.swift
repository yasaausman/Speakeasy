import SwiftUI

/// Multi-call comparison (C1), warm-human world: a honey-lit winner card, then
/// the ranked list of every place we called, best first.
struct RankedResultsView: View {
    let ranked: [RankedResult]
    let winnerReason: String?
    var onReplay: () -> Void
    var onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                if let reason = winnerReason, !reason.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        Label("Best option", systemImage: "trophy.fill")
                            .font(.headline)
                            .foregroundStyle(Theme.honey)
                        Text(reason)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(Theme.ink)
                        Button(action: onReplay) {
                            Label("Play", systemImage: "speaker.wave.2.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.honey)
                                .padding(.vertical, 9).padding(.horizontal, 15)
                                .background(Capsule().fill(Theme.honey.opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                    .padding(Theme.Space.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .softCard(Theme.honey.opacity(0.12), stroke: Theme.honey.opacity(0.35))
                }

                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: Theme.Space.s) {
                        Text("\(index + 1)")
                            .font(.headline.weight(.bold).monospacedDigit())
                            .foregroundStyle(index == 0 ? .white : Theme.inkSecondary)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(index == 0 ? Theme.honey : Theme.surfaceSunk))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.number)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Text(item.result.outcomeUserLang ?? item.result.outcome)
                                .font(.footnote)
                                .foregroundStyle(Theme.inkSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(Theme.Space.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .softCard(Theme.surface)
                }

                Button("New request", action: onDone)
                    .buttonStyle(PrimaryPill())
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Space.xs)
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.m)
        }
    }
}
