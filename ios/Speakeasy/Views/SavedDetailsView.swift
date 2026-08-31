import SwiftUI

/// The facts vault: details the agent can share when a rep asks, so real tasks
/// (booking, refills) actually complete. Stored locally on device.
struct SavedDetailsView: View {
    @Binding var details: SavedDetails

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.m) {
                Text("Speakeasy shares these only when a receptionist asks — so the call can finish without calling you back.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Space.xs)

                VStack(spacing: 0) {
                    field("Full name", "e.g. Alex Rivera", $details.fullName, icon: "person.fill")
                    divider
                    field("Callback number", "+1 …", $details.callbackNumber, icon: "phone.fill", keyboard: .phonePad)
                    divider
                    field("Insurance", "e.g. Medicaid", $details.insurance, icon: "cross.case.fill")
                    divider
                    field("Date of birth", "MM / DD / YYYY", $details.dateOfBirth, icon: "calendar", keyboard: .numbersAndPunctuation)
                    divider
                    field("Address", "Street, City, ZIP", $details.address, icon: "house.fill")
                }
                .padding(.vertical, 4)
                .softCard(Theme.surface)

                Label("Saved automatically", systemImage: "checkmark.seal.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.success)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, Theme.Space.xs)
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.m)
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 56)
    }

    private func field(_ label: String, _ placeholder: String, _ binding: Binding<String>, icon: String, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: Theme.Space.s) {
            ZStack {
                Circle().fill(Theme.primary.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.footnote.weight(.semibold)).foregroundStyle(Theme.primary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption).foregroundStyle(Theme.inkSecondary)
                TextField(placeholder, text: binding)
                    .font(.body).foregroundStyle(Theme.ink)
                    .keyboardType(keyboard)
                    .autocorrectionDisabled()
            }
        }
        .padding(.vertical, 12).padding(.horizontal, Theme.Space.m)
    }
}
