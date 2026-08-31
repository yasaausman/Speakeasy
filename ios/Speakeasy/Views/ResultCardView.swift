import SwiftUI

/// Single-call result, warm-human world: outcome, a confirmation chip, replay,
/// and a collapsible English transcript.
struct ResultCardView: View {
    let result: CallResult
    var onReplay: () -> Void
    var onDone: () -> Void

    @State private var showTranscript = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    HStack(spacing: Theme.Space.s) {
                        ZStack {
                            Circle().fill(statusColor.opacity(0.16)).frame(width: 46, height: 46)
                            Image(systemName: statusIcon)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(statusColor)
                        }
                        Text(statusTitle)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                    }

                    Text(result.outcomeUserLang ?? result.outcome)
                        .font(.title3)
                        .foregroundStyle(Theme.ink)

                    if !result.confirmationNumbers.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirmation")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.inkSecondary)
                                .textCase(.uppercase)
                            Text(result.confirmationNumbers.joined(separator: "  "))
                                .font(.title.weight(.bold).monospacedDigit())
                                .foregroundStyle(Theme.primaryDeep)
                                .padding(.vertical, 10).padding(.horizontal, 16)
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous).fill(Theme.primary.opacity(0.12)))
                        }
                    }

                    Button(action: onReplay) {
                        Label("Play narration", systemImage: "speaker.wave.2.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.primary)
                            .padding(.vertical, 10).padding(.horizontal, 16)
                            .background(Capsule().fill(Theme.primary.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(Theme.Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .softCard(Theme.surface)

                DisclosureGroup(isExpanded: $showTranscript) {
                    Text(result.transcript)
                        .font(.footnote.monospaced())
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Theme.Space.s)
                } label: {
                    Label("English transcript", systemImage: "text.alignleft")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.primary)
                .padding(Theme.Space.m)
                .softCard(Theme.surfaceSunk, stroke: .clear)

                Button("New request", action: onDone)
                    .buttonStyle(PrimaryPill())
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.m)
        }
    }

    private var statusTitle: String {
        switch result.status {
        case .completed: return "Done"
        case .no_answer: return "No answer"
        case .voicemail: return "Voicemail"
        case .busy: return "Line busy"
        case .declined: return "Declined"
        default: return "Couldn't finish"
        }
    }
    private var statusIcon: String {
        switch result.status {
        case .completed: return "checkmark"
        case .no_answer, .voicemail, .busy: return "phone.badge.waveform.fill"
        default: return "exclamationmark"
        }
    }
    private var statusColor: Color {
        switch result.status {
        case .completed: return Theme.success
        case .no_answer, .voicemail, .busy: return Theme.honey
        default: return Theme.primaryDeep
        }
    }
}
