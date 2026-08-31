import SwiftUI

/// Multi-call comparison result (C1): a highlighted winner rationale plus the
/// ranked list of every place we called, best first.
struct RankedResultsView: View {
    let ranked: [RankedResult]
    let winnerReason: String?
    var onReplay: () -> Void
    var onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let reason = winnerReason, !reason.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Best option", systemImage: "trophy.fill")
                            .font(.headline).foregroundStyle(.orange)
                        Text(reason).font(.body)
                        Button(action: onReplay) {
                            Label("Play", systemImage: "play.circle.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.orange.opacity(0.10)))
                }

                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.headline.monospacedDigit())
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(index == 0 ? Color.orange : Color.secondary.opacity(0.25)))
                            .foregroundStyle(index == 0 ? .white : .primary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.number).font(.subheadline.weight(.semibold))
                            Text(item.result.outcomeUserLang ?? item.result.outcome)
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                }

                Button("New request", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
    }
}
