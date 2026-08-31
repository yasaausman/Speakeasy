import SwiftUI

/// The single voice-first screen. Renders per phase (build-plan §9):
/// mic + text box → confirm/edit → live status → result card.
struct ContentView: View {
    @StateObject private var vm = SessionViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
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
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Speakeasy")
            .animation(.easeInOut, value: vm.phase)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Language", selection: $vm.language) {
                            ForEach(vm.languages) { lang in
                                Text("\(lang.endonym) — \(lang.name)").tag(lang)
                            }
                        }
                    } label: {
                        Label(vm.language.endonym, systemImage: "globe")
                    }
                    // Don't switch language mid-call.
                    .disabled(!canPickLanguage)
                }
            }
        }
        // Flip the whole UI for right-to-left languages (Arabic).
        .environment(\.layoutDirection, vm.language.rtl ? .rightToLeft : .leftToRight)
    }

    private var canPickLanguage: Bool {
        vm.phase == .idle || vm.phase == .collecting || vm.phase == .failed
    }

    // MARK: Input (voice + text)
    private var inputView: some View {
        VStack(spacing: 20) {
            Spacer()
            // Press-and-hold to talk (native SFSpeechRecognizer).
            Image(systemName: vm.speech.isListening ? "waveform" : "mic.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white)
                .frame(width: 120, height: 120)
                .background(Circle().fill(vm.speech.isListening ? .red : .blue))
                .scaleEffect(vm.speech.isListening ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 0.25), value: vm.speech.isListening)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in vm.startVoiceInput() }
                        .onEnded { _ in vm.endVoiceInput() }
                )

            Text(vm.speech.isListening
                 ? (vm.speech.partialText.isEmpty ? "Listening…" : vm.speech.partialText)
                 : "Hold to speak — or type your request below")
                .font(vm.speech.isListening ? .body : .subheadline)
                .foregroundStyle(vm.speech.isListening ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .frame(minHeight: 44)

            HStack {
                TextField("What do you need? (e.g. book a dentist appointment)", text: $vm.draftText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button("Go") { vm.submitGoal(vm.draftText) }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.draftText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Toggle(isOn: $vm.compareMode) {
                Label("Compare 3 places, pick the best", systemImage: "list.number")
                    .font(.subheadline)
            }
            .toggleStyle(.switch)

            if let err = vm.errorMessage {
                Text(err).font(.footnote).foregroundStyle(.red)
            }
            Spacer()
        }
    }

    // MARK: Confirm gate
    private var confirmView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.bubble")
                .font(.system(size: 40)).foregroundStyle(.blue)
            Text("Did I get this right?").font(.title2.bold())
            if let u = vm.understanding {
                Text(u.readbackUserLang)
                    .font(.body).multilineTextAlignment(.center)
                    .padding().background(RoundedRectangle(cornerRadius: 12).fill(.blue.opacity(0.08)))
                Text("I'll call \(u.targetNumber)").font(.footnote).foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                Button("Edit", role: .cancel) { vm.reject() }
                    .buttonStyle(.bordered)
                Button("Yes, call") { vm.confirmAndCall() }
                    .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
    }

    // MARK: Live call status
    private var callingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().scaleEffect(1.6)
            Text(vm.statusLine ?? "Calling…").font(.title3).foregroundStyle(.secondary)
            Spacer()
        }
    }
}

#Preview { ContentView() }
