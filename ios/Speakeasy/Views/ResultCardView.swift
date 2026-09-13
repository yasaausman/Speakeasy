import SwiftUI

/// Single-call result: outcome, a confidence badge, a confirmation chip, replay,
/// Add-to-Calendar, and a collapsible English transcript. Confetti on success.
struct ResultCardView: View {
    let result: CallResult
    @ObservedObject var store: AppStore
    var business: FoundBusiness? = nil
    var onCheck: (() -> Void)? = nil
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
    @State private var showDateReview = false
    @State private var selectedDate = Date().addingTimeInterval(86400)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private enum CalState { case idle, saving, added, denied }

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
                        Text(statusTitle).accessibilityIdentifier("result-status")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        if let c = result.confidence, result.isSuccessful {
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

                    if let business {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(business.name).font(.headline)
                            if let address = business.address { Text(address).font(.subheadline) }
                            Text(business.phone).font(.subheadline.monospacedDigit())
                        }
                        .foregroundStyle(Theme.inkSecondary)
                    }
                    if result.isSuccessful, let time = result.appointmentText {
                        Label(result.appointmentUserLang ?? time, systemImage: "calendar")
                            .font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                    }
                    if result.status == .pending {
                        Text(F.t("The call may still be active. Checking its status will not place another call.", lang))
                            .font(.subheadline).foregroundStyle(Theme.inkSecondary)
                        if result.runId != nil, let onCheck {
                            Button(F.t("Check status", lang), action: onCheck).buttonStyle(PrimaryPill())
                        } else {
                            Text(F.t("Check CALL-E call history to resolve this call before trying again.", lang))
                                .font(.subheadline)
                        }
                    }
                    if let gaps = result.gaps, let firstGap = gaps.first {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(F.t("Requested information", lang), systemImage: "exclamationmark.bubble.fill")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accentInk)
                            Text((result.gapsUserLang ?? gaps).joined(separator: ", ") + "\n" + F.t("Add the missing information. You will review the next call before it starts.", lang))
                                .font(.footnote).foregroundStyle(Theme.inkSecondary)
                            HStack(spacing: Theme.Space.s) {
                                TextField(F.t("Your answer", lang), text: $gapAnswer)
                                    .font(.subheadline).foregroundStyle(Theme.ink)
                                    .padding(.vertical, 10).padding(.horizontal, 14)
                                    .background(Capsule().fill(Theme.surface))
                                    .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                                    .autocorrectionDisabled()
                                Button {
                                    onAnswerGap(firstGap, gapAnswer); gapAnswer = ""
                                } label: {
                                    Image(systemName: "arrow.up.circle.fill").font(.title2).frame(minWidth: 44, minHeight: 44)
                                        .foregroundStyle(gapAnswer.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.inkSecondary.opacity(0.5) : Theme.accent)
                                }
                                .accessibilityLabel(F.t("Send answer", lang))
                                .disabled(gapAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                        .padding(Theme.Space.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent.opacity(0.10)))
                    }

                    if let evidence = result.evidenceUserLang ?? result.evidence, !evidence.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(evidence, id: \.self) { line in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "text.quote").font(.caption2.weight(.bold)).foregroundStyle(Theme.inkSecondary).padding(.top, 2)
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

                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        Button(action: onReplay) {
                            Label(isSpeaking ? L.t(.stop, lang) : L.t(.play, lang),
                                  systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.actionInk)
                                .padding(.vertical, 10).padding(.horizontal, 16)
                                .background(Capsule().fill(Theme.primary.opacity(0.12)))
                        }
                        .buttonStyle(.plain)

                        if result.isSuccessful, let appt = result.appointmentText {
                            Button {
                                if CalendarService.parseDate(appt) != nil { addToCalendar(appt) }
                                else { showDateReview = true }
                            } label: {
                                Label(calLabel, systemImage: calIcon)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.accentInk)
                                    .padding(.vertical, 10).padding(.horizontal, 16)
                                    .background(Capsule().fill(Theme.accent.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                            .disabled(calState == .added || calState == .saving)
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
                    Label(F.t("English transcript", lang), systemImage: "text.alignleft")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.primary)
                .padding(Theme.Space.m)
                .softCard(Theme.surfaceSunk, stroke: .clear)

                if result.status != .pending {
                VStack(spacing: Theme.Space.s) {
                    if result.canRetry { Button { onRetry() } label: {
                        Label(L.t(.tryAgain, lang), systemImage: "arrow.clockwise")
                    }.buttonStyle(SoftPill()) }
                    Button(L.t(.newRequest, lang), action: onDone).buttonStyle(PrimaryPill())
                }
                .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.m)
        }
        .onAppear {
            autoAddIfNeeded()
            if result.isSuccessful { Haptics.success() }
        }

        if result.isSuccessful && !reduceMotion {
            ConfettiView()
        }
        }
        .sheet(isPresented: $showDateReview) {
            NavigationStack {
                Form {
                    Text(F.t("Choose the exact date and time confirmed by the business.", lang))
                    Text(result.appointmentText ?? "")
                    DatePicker(F.t("Review date and time", lang), selection: $selectedDate, in: Date()...)
                    Button(F.t("Save appointment", lang)) {
                        showDateReview = false
                        addToCalendar(result.appointmentText ?? "", confirmedDate: selectedDate)
                    }
                }
                .navigationTitle(F.t("Review date and time", lang))
                .toolbar { Button(F.t("Cancel", lang)) { showDateReview = false } }
            }
            .environment(\.locale, Locale(identifier: lang))
        }
    }

    /// Auto-create the calendar event on a successful booking (if enabled).
    private var calendarID: String {
        result.runId ?? "\(phoneNumber ?? "")|\(result.appointmentText ?? "")|\(result.confirmationNumbers.joined())"
    }

    private func autoAddIfNeeded() {
        if store.hasCalendarEvent(calendarID) { calState = .added; return }
        guard store.autoAddToCalendar, calState == .idle,
              result.isSuccessful, let appt = result.appointmentText, CalendarService.parseDate(appt) != nil else { return }
        addToCalendar(appt)
    }

    private var calLabel: String {
        switch calState {
        case .added: return L.t(.added, lang)
        case .denied: return F.t("Calendar unavailable", lang)
        case .saving: return "…"
        case .idle: return CalendarService.parseDate(result.appointmentText ?? "") == nil ? F.t("Review date and time", lang) : L.t(.addToCalendar, lang)
        }
    }
    private var calIcon: String {
        switch calState { case .added: return "checkmark"; case .denied: return "calendar.badge.exclamationmark"; case .idle, .saving: return "calendar.badge.plus" }
    }
    private func addToCalendar(_ appt: String, confirmedDate: Date? = nil) {
        guard result.isSuccessful, !store.hasCalendarEvent(calendarID), calState != .saving, calState != .added else { return }
        calState = .saving
        Task {
            let title = result.provider.map { "Appointment — \($0)" } ?? "Appointment"
            let outcome = await CalendarService.addEvent(
                title: title,
                notes: result.outcome,
                appointmentText: appt,
                confirmedDate: confirmedDate,
                location: business?.address,
                phoneToReschedule: phoneNumber)
            await MainActor.run {
                if outcome == .added { store.recordCalendarEvent(calendarID) }
                calState = (outcome == .added) ? .added : .denied
            }
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
        case .pending: return F.t("Outcome pending", lang)
        case .completed:
            if result.needsInformation { return F.t("Needs your answer", lang) }
            if result.isSuccessful { return F.t(result.appointmentText != nil ? "Appointment confirmed" : "Task completed", lang) }
            return F.t("Not confirmed", lang)
        case .no_answer: return L.t(.statusNoAnswer, lang)
        case .voicemail: return L.t(.statusVoicemail, lang)
        case .busy: return L.t(.statusBusy, lang)
        case .declined: return L.t(.statusDeclined, lang)
        default: return L.t(.statusFailed, lang)
        }
    }
    private var statusIcon: String {
        switch result.status {
        case .completed: return result.isSuccessful ? "checkmark" : "exclamationmark.bubble"
        case .pending: return "clock"
        case .no_answer, .voicemail, .busy: return "phone.badge.waveform.fill"
        default: return "exclamationmark"
        }
    }
    private var statusColor: Color {
        switch result.status {
        case .completed: return result.isSuccessful ? Theme.success : Theme.inkSecondary
        case .pending: return Theme.inkSecondary
        case .no_answer, .voicemail, .busy: return Theme.accent
        default: return Theme.primaryDeep
        }
    }
}
