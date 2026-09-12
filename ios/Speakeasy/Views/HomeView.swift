import SwiftUI

/// The voice-first call flow: speak/type → confirm gate → live call → result.
struct HomeView: View {
    @ObservedObject var vm: SessionViewModel
    @State private var noteText = ""
    @State private var showNumberSheet = false
    @State private var showNote = false

    var body: some View {
        Group {
            switch vm.phase {
            case .idle, .collecting, .failed:
                inputView
            case .confirming:
                confirmView
            case .calling, .polling, .narrating:
                callingView
            case .done:
                if let options = vm.options, !options.isEmpty {
                    SlotPickerView(options: options,
                                   intro: vm.result?.outcomeUserLang ?? vm.result?.outcome,
                                   onPick: { vm.pickSlot($0) },
                                   onDone: vm.reset)
                } else if let ranked = vm.ranked {
                    RankedResultsView(ranked: ranked, winnerReason: vm.winnerReason,
                                      onReplay: { vm.speakResult() },
                                      onBook: { vm.bookWinner(number: $0) },
                                      onDone: vm.reset)
                } else if let r = vm.result {
                    ResultCardView(result: r, store: vm.store,
                                   phoneNumber: vm.understanding?.targetNumber,
                                   onReplay: { vm.speakResult() }, onRetry: vm.retry,
                                   onAnswerGap: { vm.answerGap($0, value: $1) }, onDone: vm.reset)
                }
            }
        }
        .transition(.opacity)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: vm.phase)
    }

    // MARK: Input
    private var inputView: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer(minLength: Theme.Space.m)

            VoiceOrb(isListening: vm.speech.isListening, hasError: vm.errorMessage != nil)
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            hideKeyboard()   // grabbing the orb puts the keyboard away
                            vm.startVoiceInput()
                        }
                        .onEnded { _ in vm.endVoiceInput() }
                )

            Group {
                if vm.isSubmitting {
                    HStack(spacing: 10) {
                        ProgressView().tint(Theme.primary)
                        Text("Understanding…")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                    }
                } else {
                    Text(vm.speech.isListening
                         ? (vm.speech.partialText.isEmpty ? "Listening…" : vm.speech.partialText)
                         : "Hold to speak — or type below")
                        .font(vm.speech.isListening ? .title3.weight(.semibold) : .callout)
                        .foregroundStyle(vm.speech.isListening ? Theme.ink : Theme.inkSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(minHeight: 52)
            .padding(.horizontal, Theme.Space.l)
            .animation(.easeInOut, value: vm.speech.isListening)
            .animation(.easeInOut, value: vm.isSubmitting)

            Spacer(minLength: 0)

            VStack(spacing: Theme.Space.s) {
                HStack(spacing: Theme.Space.s) {
                    TextField("What do you need?", text: $vm.draftText, axis: .vertical)
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 14).padding(.horizontal, 18)
                        .background(Capsule().fill(Theme.surface))
                        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") { hideKeyboard() }
                            }
                        }

                    Button { vm.submitGoal(vm.draftText) } label: {
                        Image(systemName: "arrow.up")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(sendDisabled ? Theme.inkSecondary.opacity(0.4) : Theme.primary))
                            .shadow(color: sendDisabled ? .clear : Theme.primary.opacity(0.35), radius: 12, y: 6)
                    }
                    .disabled(sendDisabled)
                    .animation(.easeInOut, value: isEmpty)
                }

                // The assistant's latest answer — in the user's language, and read
                // aloud (tap the speaker to replay). Replaces the old mode toggles;
                // the backend now infers compare / availability from the goal.
                if let msg = vm.assistantMessage {
                    HStack(alignment: .top, spacing: Theme.Space.xs) {
                        Image(systemName: "quote.bubble.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.primary)
                            .accessibilityHidden(true)
                        Text(msg)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button { vm.replayAssistant() } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.subheadline)
                                .foregroundStyle(Theme.primary)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Theme.primary.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Play aloud")
                    }
                    .padding(.vertical, 14).padding(.horizontal, 16)
                    .softCard(Theme.surface)
                    .transition(.opacity)
                }

                if let err = vm.errorMessage {
                    ErrorBanner(message: err) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            vm.errorMessage = nil
                        }
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: vm.errorMessage)
            .animation(.easeInOut, value: vm.assistantMessage)
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.bottom, Theme.Space.m)
        // Tap any empty area to dismiss the keyboard (sits behind the controls,
        // so the orb, cards, and text field still get their taps first).
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { hideKeyboard() }
        )
        // …and a swipe down anywhere does the same.
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height > 40 { hideKeyboard() }
                }
        )
    }

    // MARK: Confirm gate
    private var confirmView: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer()
            ZStack {
                Circle().fill(Theme.primary.opacity(0.14)).frame(width: 84, height: 84)
                Image(systemName: "quote.bubble.fill").font(.system(size: 34, weight: .semibold)).foregroundStyle(Theme.primary)
            }
            Text("Did I get this right?").font(.title.weight(.bold)).foregroundStyle(Theme.ink)

            if let u = vm.understanding {
                Text(u.readbackUserLang)
                    .font(.title3).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(Theme.Space.l).frame(maxWidth: .infinity)
                    .softCard(Theme.surface)

                if (u.businesses?.count ?? 0) > 1 {
                    // Compare mode — the places we'll call, so a wrong lookup is visible.
                    VStack(spacing: 10) {
                        ForEach(u.businesses ?? []) { biz in
                            VStack(alignment: .leading, spacing: 2) {
                                Label("\(biz.name) · \(biz.phone)", systemImage: "phone.fill")
                                    .font(.subheadline.weight(.medium)).foregroundStyle(Theme.inkSecondary)
                                if let addr = biz.address {
                                    Text(addr).font(.caption).foregroundStyle(Theme.inkSecondary).padding(.leading, 22)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    VStack(spacing: 4) {
                        Button { showNumberSheet = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "phone.fill")
                                Text(u.businesses?.first.map { "\($0.name) · \($0.phone)" } ?? u.targetNumber)
                                Image(systemName: "pencil").font(.caption2)
                            }
                            .font(.subheadline.weight(.medium)).foregroundStyle(Theme.primary)
                        }
                        if let addr = u.businesses?.first?.address {
                            Text(addr).font(.caption).foregroundStyle(Theme.inkSecondary)
                        }
                    }
                }

                // Editable brief: add a detail before calling.
                if showNote {
                    HStack(spacing: Theme.Space.s) {
                        TextField("e.g. mornings only, take Medicaid", text: $noteText)
                            .font(.subheadline).foregroundStyle(Theme.ink)
                            .padding(.vertical, 10).padding(.horizontal, 14)
                            .background(Capsule().fill(Theme.surface))
                            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                        Button("Add") { vm.amend(noteText); noteText = ""; showNote = false }
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.primary)
                            .disabled(noteText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, Theme.Space.xs)
                } else {
                    Button { showNote = true } label: {
                        Label("Add a detail", systemImage: "plus.circle")
                            .font(.subheadline.weight(.medium)).foregroundStyle(Theme.inkSecondary)
                    }
                }
            }

            Spacer()

            HStack(spacing: Theme.Space.s) {
                Button("Edit") { vm.reject() }.buttonStyle(SoftPill())
                Button { vm.confirmAndCall() } label: {
                    Label("Yes, call", systemImage: "phone.arrow.up.right.fill")
                }.buttonStyle(PrimaryPill())
            }
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.bottom, Theme.Space.l)
        .sheet(isPresented: $showNumberSheet) {
            ChangeNumberSheet(current: vm.targetNumber ?? "") { number in
                vm.targetNumber = number
                vm.submitGoal(vm.lastGoalText)   // re-run with the chosen number
            }
        }
    }

    // MARK: Live call (with streaming transcript)
    private var callingView: some View {
        VStack(spacing: Theme.Space.m) {
            HStack(spacing: Theme.Space.s) {
                ZStack {
                    Circle().fill(Theme.primary.opacity(0.14)).frame(width: 52, height: 52)
                    Image(systemName: "phone.connection.fill").font(.title3).foregroundStyle(Theme.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("On the call").font(.headline).foregroundStyle(Theme.ink)
                    Text(vm.statusLine ?? "Connecting…").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                ProgressView().tint(Theme.primary)
            }
            .padding(.top, Theme.Space.s)

            if vm.activity.isEmpty {
                Spacer()
                VoiceOrb(isListening: false)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(vm.activity.enumerated()), id: \.offset) { i, line in
                                transcriptLine(line).id(i)
                            }
                        }
                        .padding(.vertical, Theme.Space.s)
                        .padding(.horizontal, Theme.Space.m)
                    }
                    .softCard(Theme.surface)
                    .onChange(of: vm.activity.count) { _, count in
                        withAnimation(.easeOut) { proxy.scrollTo(count - 1, anchor: .bottom) }
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.bottom, Theme.Space.m)
    }

    @ViewBuilder private func transcriptLine(_ line: String) -> some View {
        if let range = line.range(of: "Bot:") {
            bubble(String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces),
                   speaker: "Agent", tint: Theme.primary, align: .leading)
        } else if let range = line.range(of: "Rep:") {
            bubble(String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces),
                   speaker: "Them", tint: Theme.accent, align: .trailing)
        } else {
            Text(line)
                .font(.footnote).foregroundStyle(Theme.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 2)
        }
    }

    private func bubble(_ text: String, speaker: String, tint: Color, align: HorizontalAlignment) -> some View {
        VStack(alignment: align == .leading ? .leading : .trailing, spacing: 3) {
            Text(speaker).font(.caption2.weight(.bold)).foregroundStyle(tint).textCase(.uppercase)
            Text(text)
                .font(.subheadline).foregroundStyle(Theme.ink)
                .padding(.vertical, 10).padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tint.opacity(0.12)))
        }
        .frame(maxWidth: .infinity, alignment: align == .leading ? .leading : .trailing)
    }

    private var isEmpty: Bool { vm.draftText.trimmingCharacters(in: .whitespaces).isEmpty }
    private var sendDisabled: Bool { isEmpty || vm.isSubmitting }

    /// Resign the keyboard (whichever text field is first responder).
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// (Removed HoldButtonStyle — a ButtonStyle's isPressed via onChange doesn't
// reliably fire press/release for push-to-talk. The mic uses a DragGesture in
// inputView instead.)

/// A soft, non-alarming inline notice for voice/mic trouble. Uses the playful
/// orange accent rather than a harsh red so a hiccup still feels friendly, and
/// always points the user at the "type below" fallback. Dismissible; driven by
/// SessionViewModel.errorMessage.
struct ErrorBanner: View {
    let message: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.xs) {
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Theme.surfaceSunk))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                .fill(Theme.accent.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }
}
