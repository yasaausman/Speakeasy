import SwiftUI

/// The single voice-first screen, warm-human world. Renders per phase:
/// speak/type → confirm gate → live status → result (single or ranked).
struct ContentView: View {
    @StateObject private var vm = SessionViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.ground.ignoresSafeArea()
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
                                              onReplay: vm.speakResult, onDone: vm.reset)
                        } else if let r = vm.result {
                            ResultCardView(result: r, onReplay: vm.speakResult, onDone: vm.reset)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            .navigationTitle("Speakeasy")
            .toolbarBackground(Theme.ground, for: .navigationBar)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: vm.phase)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { languageMenu }
            }
        }
        .environment(\.layoutDirection, vm.language.rtl ? .rightToLeft : .leftToRight)
    }

    // MARK: Language picker
    private var languageMenu: some View {
        Menu {
            Picker("Language", selection: $vm.language) {
                ForEach(vm.languages) { lang in
                    Text("\(lang.endonym) — \(lang.name)").tag(lang)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                Text(vm.language.endonym).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Theme.primary)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .disabled(!canPickLanguage)
    }

    private var canPickLanguage: Bool {
        vm.phase == .idle || vm.phase == .collecting || vm.phase == .failed
    }

    // MARK: Input (voice + text)
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

                    Button {
                        vm.submitGoal(vm.draftText)
                    } label: {
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
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
            Text("Did I get this right?")
                .font(.title.weight(.bold))
                .foregroundStyle(Theme.ink)

            if let u = vm.understanding {
                Text(u.readbackUserLang)
                    .font(.title3)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(Theme.Space.l)
                    .frame(maxWidth: .infinity)
                    .softCard(Theme.surface)

                Label(u.targetNumber, systemImage: "phone.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.inkSecondary)
            }

            Spacer()

            HStack(spacing: Theme.Space.s) {
                Button("Edit") { vm.reject() }.buttonStyle(SoftPill())
                Button {
                    vm.confirmAndCall()
                } label: {
                    Label("Yes, call", systemImage: "phone.arrow.up.right.fill")
                }
                .buttonStyle(PrimaryPill())
            }
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.bottom, Theme.Space.l)
    }

    // MARK: Live call status
    private var callingView: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer()
            VoiceOrb(isListening: false)
                .overlay(alignment: .bottom) {
                    ProgressView()
                        .tint(.white)
                        .offset(y: -46)
                }
            Text(vm.statusLine ?? "Calling…")
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.xl)
            Spacer()
        }
    }

    private var isEmpty: Bool {
        vm.draftText.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

#Preview { ContentView() }
