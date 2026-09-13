import SwiftUI

/// Speculative booking (C4): after a discovery call, the user picks one of the
/// available times and Speakeasy calls back to book that exact slot.
struct SlotPickerView: View {
    let options: [SlotOption]
    let intro: String?
    var lang: String = "en"
    var onPick: (SlotOption) -> Void
    var onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Label(F.t("Available times", lang), systemImage: "clock.badge.checkmark.fill")
                        .font(.headline).foregroundStyle(Theme.actionInk)
                    if let intro, !intro.isEmpty {
                        Text(intro).font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    }
                    Text(F.t("Pick a time. Review the booking call before it starts.", lang))
                        .font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                }
                .padding(Theme.Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .softCard(Theme.surface)

                ForEach(options) { opt in
                    Button { onPick(opt) } label: {
                        HStack(spacing: Theme.Space.s) {
                            ZStack {
                                Circle().fill(Theme.primary.opacity(0.12)).frame(width: 40, height: 40)
                                Image(systemName: "calendar").font(.body.weight(.semibold)).foregroundStyle(Theme.actionInk)
                            }
                            Text(opt.display)
                                .font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3).foregroundStyle(Theme.actionInk)
                        }
                        .padding(Theme.Space.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .softCard(Theme.surface)
                    }
                    .buttonStyle(.plain)
                }

                Button(F.t("None of these — start over", lang), action: onDone)
                    .buttonStyle(SoftPill())
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Space.xs)
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.m)
        }
    }
}
