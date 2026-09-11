import SwiftUI

/// The facts vault + booking preferences: details the agent shares when asked,
/// preferences it decides from, and calendar settings.
struct SavedDetailsView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.m) {
                Text("Speakeasy shares these only when a receptionist asks — so the call can finish without calling you back.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Space.xs)

                // Facts vault
                VStack(spacing: 0) {
                    field("Full name", "e.g. Alex Rivera", $store.details.fullName, icon: "person.fill")
                    divider
                    field("Callback number", "+1 …", $store.details.callbackNumber, icon: "phone.fill", keyboard: .phonePad)
                    divider
                    field("Insurance", "e.g. Medicaid", $store.details.insurance, icon: "cross.case.fill")
                    divider
                    field("Date of birth", "MM / DD / YYYY", $store.details.dateOfBirth, icon: "calendar", keyboard: .numbersAndPunctuation)
                    divider
                    field("Address", "Street, City, ZIP", $store.details.address, icon: "house.fill")
                }
                .padding(.vertical, 4)
                .softCard(Theme.surface)

                // Booking preferences
                sectionHeader("Booking preferences", "So I can handle an unavailable slot without calling you back.")
                VStack(spacing: 0) {
                    field("Preferred times", "e.g. Saturday 2–4pm", $store.details.preferredTimes, icon: "star.fill")
                    divider
                    field("If unavailable", "e.g. any Sat afternoon, else Sun morning", $store.details.fallbackTimes, icon: "arrow.uturn.down")
                    divider
                    field("Avoid", "e.g. before 10am", $store.details.avoid, icon: "nosign")
                    divider
                    field("Budget", "e.g. under $40", $store.details.budget, icon: "dollarsign.circle.fill")
                }
                .padding(.vertical, 4)
                .softCard(Theme.surface)

                // Calendar
                sectionHeader("Calendar", nil)
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    settingToggle("Add bookings to Calendar", "Create a calendar event automatically when an appointment is booked.",
                                  systemImage: "calendar.badge.plus", isOn: $store.autoAddToCalendar)
                    Rectangle().fill(Theme.hairline).frame(height: 1)
                    settingToggle("Use my availability", "Let the agent see your free times so it only asks for slots you're open for.",
                                  systemImage: "calendar.badge.clock", isOn: $store.useCalendarAvailability)
                }
                .padding(Theme.Space.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .softCard(Theme.surface)

                // Accessibility
                sectionHeader("Accessibility", nil)
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    settingToggle("Text-only mode", "For Deaf or hard-of-hearing users — no spoken audio; everything stays on screen.",
                                  systemImage: "ear.trianglebadge.exclamationmark", isOn: $store.textForward)
                }
                .padding(Theme.Space.m)
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private func sectionHeader(_ title: String, _ subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline).foregroundStyle(Theme.ink)
            if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(Theme.inkSecondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Space.xs)
        .padding(.top, Theme.Space.s)
    }

    private func settingToggle(_ title: String, _ subtitle: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: isOn) {
                Label(title, systemImage: systemImage)
                    .font(.body.weight(.medium)).foregroundStyle(Theme.ink)
            }
            .tint(Theme.primary)
            Text(subtitle).font(.footnote).foregroundStyle(Theme.inkSecondary)
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
