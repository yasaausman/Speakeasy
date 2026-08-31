import SwiftUI

/// Result card: outcome, confirmation number, replay, and a collapsible English
/// transcript (handy for the demo video).
struct ResultCardView: View {
    let result: CallResult
    var onReplay: () -> Void
    var onDone: () -> Void

    @State private var showTranscript = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: statusIcon).foregroundStyle(statusColor)
                    Text(result.status.rawValue.capitalized).font(.headline)
                }

                Text(result.outcomeUserLang ?? result.outcome)
                    .font(.body)

                if !result.confirmationNumbers.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Confirmation").font(.caption).foregroundStyle(.secondary)
                        // TODO(Phase M3): read digits aloud one by one on tap.
                        Text(result.confirmationNumbers.joined(separator: ", "))
                            .font(.title3.monospaced().bold())
                    }
                }

                Button(action: onReplay) {
                    Label("Play narration", systemImage: "play.circle.fill")
                }
                .buttonStyle(.bordered)

                DisclosureGroup("English transcript", isExpanded: $showTranscript) {
                    Text(result.transcript)
                        .font(.footnote.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("New request", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        }
    }

    private var statusIcon: String {
        switch result.status {
        case .completed: return "checkmark.circle.fill"
        case .no_answer, .voicemail, .busy: return "phone.badge.waveform"
        default: return "exclamationmark.triangle.fill"
        }
    }
    private var statusColor: Color {
        result.status == .completed ? .green : .orange
    }
}
