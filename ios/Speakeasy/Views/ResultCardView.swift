import SwiftUI

/// Single-call result, warm-human world: outcome, a confirmation chip, replay,
/// and a collapsible English transcript.
struct ResultCardView: View {
    let result: CallResult
    var onReplay: () -> Void
    var onRetry: () -> Void
    var onDone: () -> Void

    @State private var showTranscript = false
    @State private var calState: CalState = .idle
    private enum CalState { case idle, added, denied }

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
                        if let c = result.confidence {
                            Label(c.label.capitalized, systemImage: "checkmark.seal.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(confidenceColor(c.label))
                                .padding(.vertical, 5).padding(.horizontal, 10)
                                .background(Capsule().fill(confidenceColor(c.label).opacity(0.14)))
                        }
                    }

                    Text(result.outcomeUserLang ?? result.outcome)
                        .font(.title3)
                        .foregroundStyle(Theme.ink)

                    if let gaps = result.gaps, !gaps.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("They need a bit more", systemImage: "exclamationmark.bubble.fill")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                            Text("The receptionist asked for: \(gaps.joined(separator: ", ")). Add it in Your details, then try again.")
                                .font(.footnote).foregroundStyle(Theme.inkSecondary)
                        }
                        .padding(Theme.Space.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent.opacity(0.10)))
                    }

                    if let evidence = result.evidence, !evidence.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(evidence, id: \.self) { line in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(Theme.success).padding(.top, 2)
                                    Text(line).font(.footnote).foregroundStyle(Theme.inkSecondary)
                                }
                            }
                        }
                    }

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

                    HStack(spacing: Theme.Space.s) {
                        Button(action: onReplay) {
                            Label("Play narration", systemImage: "speaker.wave.2.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.primary)
                                .padding(.vertical, 10).padding(.horizontal, 16)
                                .background(Capsule().fill(Theme.primary.opacity(0.12)))
                        }
                        .buttonStyle(.plain)

                        if let appt = result.appointmentText {
                            Button { addToCalendar(appt) } label: {
                                Label(calLabel, systemImage: calIcon)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                                    .padding(.vertical, 10).padding(.horizontal, 16)
                                    .background(Capsule().fill(Theme.accent.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                            .disabled(calState == .added)
                        }
                    }
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

                HStack(spacing: Theme.Space.s) {
                    Button { onRetry() } label: {
                        Label("Try again", systemImage: "arrow.clockwise")
                    }.buttonStyle(SoftPill())
                    Button("New request", action: onDone).buttonStyle(PrimaryPill())
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.m)
        }
    }

    private var calLabel: String {
        switch calState { case .added: return "Added"; case .denied: return "Calendar off"; case .idle: return "Add to Calendar" }
    }
    private var calIcon: String {
        switch calState { case .added: return "checkmark"; case .denied: return "calendar.badge.exclamationmark"; case .idle: return "calendar.badge.plus" }
    }
    private func addToCalendar(_ appt: String) {
        Task {
            let title = result.provider.map { "Appointment — \($0)" } ?? "Appointment"
            let outcome = await CalendarService.addEvent(title: title, notes: result.outcome, appointmentText: appt)
            await MainActor.run { calState = (outcome == .added) ? .added : .denied }
        }
    }

    private func confidenceColor(_ label: String) -> Color {
        switch label.lowercased() {
        case "high": return Theme.success
        case "medium": return Theme.accent
        default: return Theme.primaryDeep
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
        case .no_answer, .voicemail, .busy: return Theme.accent
        default: return Theme.primaryDeep
        }
    }
}
