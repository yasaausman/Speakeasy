import SwiftUI

/// Single-call result: outcome, a confidence badge, a confirmation chip, replay,
/// Add-to-Calendar, and a collapsible English transcript. Confetti on success.
struct ResultCardView: View {
    let result: CallResult
    @ObservedObject var store: AppStore
    var phoneNumber: String?
    var lang: String = "en"
    var onReplay: () -> Void
    var isSpeaking: Bool = false
    var onRetry: () -> Void
    var onAnswerGap: (String, String) -> Void
    var onDone: () -> Void

    @State private var showTranscript = false
    @State private var calState: CalState = .idle
    @State private var gapAnswer = ""
    private enum CalState { case idle, added, denied }

    var body: some View {
        ZStack {
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
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.vertical, 5).padding(.horizontal, 10)
                                .background(Capsule().fill(confidenceColor(c.label).opacity(0.14)))
                                .accessibilityLabel("Confidence: \(c.label)")
                        }
                    }

                    Text(result.outcomeUserLang ?? result.outcome)
                        .font(.title3)
                        .foregroundStyle(Theme.ink)

                    if let gaps = result.gaps, let firstGap = gaps.first {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("They need a bit more", systemImage: "exclamationmark.bubble.fill")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                            Text("The receptionist asked for: \(gaps.joined(separator: ", ")). Add it and I'll call back.")
                                .font(.footnote).foregroundStyle(Theme.inkSecondary)
                            HStack(spacing: Theme.Space.s) {
                                TextField("Your \(firstGap)", text: $gapAnswer)
                                    .font(.subheadline).foregroundStyle(Theme.ink)
                                    .padding(.vertical, 10).padding(.horizontal, 14)
                                    .background(Capsule().fill(Theme.surface))
                                    .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                                    .autocorrectionDisabled()
                                Button {
                                    onAnswerGap(firstGap, gapAnswer); gapAnswer = ""
                                } label: {
                                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                                        .foregroundStyle(gapAnswer.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.inkSecondary.opacity(0.5) : Theme.accent)
                                }
                                .disabled(gapAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
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
                            Text(L.t(.confirmation, lang))
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
                            Label(isSpeaking ? L.t(.stop, lang) : L.t(.play, lang),
                                  systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
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
                        Label(L.t(.tryAgain, lang), systemImage: "arrow.clockwise")
                    }.buttonStyle(SoftPill())
                    Button(L.t(.newRequest, lang), action: onDone).buttonStyle(PrimaryPill())
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.m)
        }
        .onAppear {
            autoAddIfNeeded()
            if result.status == .completed { Haptics.success() }
        }

        if result.status == .completed {
            ConfettiView()
        }
        }
    }

    /// Auto-create the calendar event on a successful booking (if enabled).
    private func autoAddIfNeeded() {
        guard store.autoAddToCalendar, calState == .idle,
              result.status == .completed, let appt = result.appointmentText else { return }
        addToCalendar(appt)
    }

    private var calLabel: String {
        switch calState {
        case .added: return L.t(.added, lang)
        case .denied: return "Calendar off"
        case .idle: return L.t(.addToCalendar, lang)
        }
    }
    private var calIcon: String {
        switch calState { case .added: return "checkmark"; case .denied: return "calendar.badge.exclamationmark"; case .idle: return "calendar.badge.plus" }
    }
    private func addToCalendar(_ appt: String) {
        Task {
            let title = result.provider.map { "Appointment — \($0)" } ?? "Appointment"
            let outcome = await CalendarService.addEvent(
                title: title,
                notes: result.outcome,
                appointmentText: appt,
                location: result.provider,
                phoneToReschedule: phoneNumber)
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
        case .completed: return L.t(.statusDone, lang)
        case .no_answer: return L.t(.statusNoAnswer, lang)
        case .voicemail: return L.t(.statusVoicemail, lang)
        case .busy: return L.t(.statusBusy, lang)
        case .declined: return L.t(.statusDeclined, lang)
        default: return L.t(.statusFailed, lang)
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
