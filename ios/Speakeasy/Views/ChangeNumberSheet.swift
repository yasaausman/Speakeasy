import SwiftUI
import ContactsUI

/// Pick who to call: from Contacts or by typing a number.
struct ChangeNumberSheet: View {
    var current: String
    var onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""
    @State private var showContacts = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.m) {
                    Button { showContacts = true } label: {
                        HStack(spacing: Theme.Space.s) {
                            ZStack {
                                Circle().fill(Theme.primary.opacity(0.12)).frame(width: 40, height: 40)
                                Image(systemName: "person.crop.circle.fill").foregroundStyle(Theme.primary)
                            }
                            Text("Choose from Contacts").font(.body.weight(.medium)).foregroundStyle(Theme.ink)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.inkSecondary)
                        }
                        .padding(Theme.Space.m)
                        .frame(maxWidth: .infinity)
                        .softCard(Theme.surface)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        Text("Or type a number").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSecondary).textCase(.uppercase)
                        HStack(spacing: Theme.Space.s) {
                            TextField("+1 …", text: $typed)
                                .keyboardType(.phonePad)
                                .font(.body).foregroundStyle(Theme.ink)
                                .padding(.vertical, 12).padding(.horizontal, 16)
                                .background(Capsule().fill(Theme.surface))
                                .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                            Button("Use") { pick(typed) }
                                .buttonStyle(PrimaryPill())
                                .disabled(normalize(typed) == nil)
                        }
                    }
                    .padding(Theme.Space.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .softCard(Theme.surface)
                }
                .padding(Theme.Space.l)
            }
            .background(Theme.ground)
            .navigationTitle("Who to call")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.foregroundStyle(Theme.primary) } }
            .sheet(isPresented: $showContacts) {
                ContactPicker { number in pick(number) }
                    .ignoresSafeArea()
            }
            .onAppear { typed = current }
        }
    }

    private func pick(_ raw: String) {
        guard let n = normalize(raw) else { return }
        onPick(n)
        dismiss()
    }

    /// Loose E.164 normalization: keep digits, assume +1 for 10-digit US numbers.
    private func normalize(_ raw: String) -> String? {
        if raw.hasPrefix("+") {
            let digits = raw.dropFirst().filter(\.isNumber)
            return digits.count >= 8 ? "+\(digits)" : nil
        }
        let digits = raw.filter(\.isNumber)
        if digits.count == 10 { return "+1\(digits)" }
        if digits.count == 11, digits.first == "1" { return "+\(digits)" }
        return digits.count >= 8 ? "+\(digits)" : nil
    }
}

/// UIKit contact picker (no Contacts permission needed — runs out-of-process).
struct ContactPicker: UIViewControllerRepresentable {
    var onPick: (String) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ vc: CNContactPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (String) -> Void
        init(onPick: @escaping (String) -> Void) { self.onPick = onPick }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect property: CNContactProperty) {
            if let phone = (property.value as? CNPhoneNumber)?.stringValue { onPick(phone) }
        }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            if let phone = contact.phoneNumbers.first?.value.stringValue { onPick(phone) }
        }
    }
}
