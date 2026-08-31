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
                    if let r = vm.result { ResultCardView(result: r, onDone: vm.reset) }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Speakeasy")
            .animation(.easeInOut, value: vm.phase)
        }
    }

    // MARK: Input (voice + text)
    private var inputView: some View {
        VStack(spacing: 20) {
            Spacer()
            // TODO(Phase M3): wire this to SpeechManager (SFSpeechRecognizer).
            Button {
                // Placeholder until voice input lands.
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 120)
                    .background(Circle().fill(.blue))
            }
            Text("Hold to speak — or type your request below")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                TextField("What do you need? (e.g. book a dentist appointment)", text: $vm.draftText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button("Go") { vm.submitGoal(vm.draftText) }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.draftText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

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
