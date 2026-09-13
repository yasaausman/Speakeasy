import SwiftUI

/// Multi-call comparison (C1): a highlighted winner card in the teal accent, then
/// the ranked list of every place we called, best first, and one-tap "book the best".
struct RankedResultsView: View {
    let ranked: [RankedResult]
    let winnerReason: String?
    var lang: String = "en"
    var onCheck: (() -> Void)? = nil
    private var hasPending: Bool { ranked.contains { $0.result.status == .pending } }
    var onReplay: () -> Void
    var onBook: (String) -> Void
    var onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                if let reason = winnerReason, !reason.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        Label(F.t(hasPending ? "Outcome pending" : "Compare results", lang), systemImage: "trophy.fill")
                            .font(.headline)
                            .foregroundStyle(Theme.accentInk)
                        Text(reason)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(Theme.ink)
                        Button(action: onReplay) {
                            Label(L.t(.play, lang), systemImage: "speaker.wave.2.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.accentInk)
                                .padding(.vertical, 9).padding(.horizontal, 15)
                                .background(Capsule().fill(Theme.accent.opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                    .padding(Theme.Space.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .softCard(Theme.accent.opacity(0.12), stroke: Theme.accent.opacity(0.35))
                }

                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: Theme.Space.s) {
                        Text("\(index + 1)")
                            .font(.headline.weight(.bold).monospacedDigit())
                            .foregroundStyle(index == 0 ? .white : Theme.inkSecondary)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(index == 0 ? Theme.accent : Theme.surfaceSunk))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.business?.name ?? item.number)
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

                if !hasPending, let winner = ranked.first, winner.result.isSuccessful {
                    Button { onBook(winner.number) } label: {
                        Label(F.t("Review and book", lang), systemImage: "phone.arrow.up.right.fill")
                    }
                    .buttonStyle(PrimaryPill())
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Space.xs)
                }

                if hasPending {
                    if let onCheck { Button(F.t("Check status", lang), action: onCheck).buttonStyle(PrimaryPill()) }
                } else { Button(L.t(.newRequest, lang), action: onDone)
                    .buttonStyle(SoftPill())
                    .frame(maxWidth: .infinity) }
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.m)
        }
    }
}
