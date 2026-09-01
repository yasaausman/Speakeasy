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
                if let ranked = vm.ranked {
                    RankedResultsView(ranked: ranked, winnerReason: vm.winnerReason,
                                      onReplay: { vm.speakResult() },
                                      onBook: { vm.bookWinner(number: $0) },
                                      onDone: vm.reset)
                } else if let r = vm.result {
                    ResultCardView(result: r, onReplay: { vm.speakResult() }, onRetry: vm.retry, onDone: vm.reset)
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

            VoiceOrb(isListening: vm.speech.isListening)
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in vm.startVoiceInput() }
                        .onEnded { _ in vm.endVoiceInput() }
                )

            Text(vm.speech.isListening
                 ? (vm.speech.partialText.isEmpty ? "Listening…" : vm.speech.partialText)
                 : "Hold to speak — or type below")
                .font(vm.speech.isListening ? .title3.weight(.semibold) : .callout)
                .foregroundStyle(vm.speech.isListening ? Theme.ink : Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(minHeight: 52)
                .padding(.horizontal, Theme.Space.l)
                .animation(.easeInOut, value: vm.speech.isListening)

            Spacer(minLength: 0)

            VStack(spacing: Theme.Space.s) {
                HStack(spacing: Theme.Space.s) {
                    TextField("What do you need?", text: $vm.draftText, axis: .vertical)
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 14).padding(.horizontal, 18)
                        .background(Capsule().fill(Theme.surface))
                        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))

                    Button { vm.submitGoal(vm.draftText) } label: {
                        Image(systemName: "arrow.up")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(isEmpty ? Theme.inkSecondary.opacity(0.4) : Theme.primary))
                            .shadow(color: isEmpty ? .clear : Theme.primary.opacity(0.35), radius: 12, y: 6)
                    }
                    .disabled(isEmpty)
                    .animation(.easeInOut, value: isEmpty)
                }

                Toggle(isOn: $vm.compareMode) {
                    Label("Compare 3 places, pick the best", systemImage: "trophy")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.primary)
                .padding(.vertical, 12).padding(.horizontal, 18)
                .softCard(Theme.surface)

                if let err = vm.errorMessage {
                    Text(err).font(.footnote).foregroundStyle(Theme.primaryDeep)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.bottom, Theme.Space.m)
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

                if vm.compareMode {
                    Label(u.targetNumber, systemImage: "phone.fill")
                        .font(.subheadline.weight(.medium)).foregroundStyle(Theme.inkSecondary)
                } else {
                    Button { showNumberSheet = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "phone.fill")
                            Text(u.targetNumber)
                            Image(systemName: "pencil").font(.caption2)
                        }
                        .font(.subheadline.weight(.medium)).foregroundStyle(Theme.primary)
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
                    }
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
}
