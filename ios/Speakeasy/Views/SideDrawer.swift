import SwiftUI

/// The burger-menu side drawer: brand, navigation rows, and a quick language row.
struct SideDrawer: View {
    let current: AppRoute
    let language: AppLanguage
    let savedCount: Int
    let historyCount: Int
    var onSelect: (AppRoute) -> Void
    var onLanguages: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Brand
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.primary).frame(width: 44, height: 44)
                    Image(systemName: "phone.fill").foregroundStyle(.white).font(.headline)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Speakeasy").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                    Text("Calls, handled").font(.caption).foregroundStyle(Theme.inkSecondary)
                }
            }
            .padding(.top, Theme.Space.xl)
            .padding(.horizontal, Theme.Space.l)
            .padding(.bottom, Theme.Space.l)

            // Nav rows
            VStack(spacing: 4) {
                row(.home)
                row(.savedDetails, badge: savedCount > 0 ? "\(savedCount)" : nil)
                row(.history, badge: historyCount > 0 ? "\(historyCount)" : nil)
                row(.about)
            }
            .padding(.horizontal, Theme.Space.s)

            Divider().overlay(Theme.hairline).padding(.vertical, Theme.Space.m).padding(.horizontal, Theme.Space.l)

            // Language quick access
            Button(action: onLanguages) {
                HStack(spacing: 14) {
                    icon("globe", tint: Theme.primary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Language").font(.body.weight(.medium)).foregroundStyle(Theme.ink)
                        Text(language.endonym).font(.caption).foregroundStyle(Theme.inkSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.inkSecondary)
                }
                .padding(.vertical, 12).padding(.horizontal, Theme.Space.m)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Theme.Space.s)

            Spacer()
        }
        .frame(maxWidth: 300, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.surface.ignoresSafeArea())
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.hairline).frame(width: 1).ignoresSafeArea() }
    }

    private func row(_ r: AppRoute, badge: String? = nil) -> some View {
        Button { onSelect(r) } label: {
            HStack(spacing: 14) {
                icon(r.icon, tint: current == r ? .white : Theme.primary, filled: current == r)
                Text(r.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(current == r ? Theme.primary : Theme.ink)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.inkSecondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Theme.surfaceSunk))
                }
            }
            .padding(.vertical, 12).padding(.horizontal, Theme.Space.m)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(current == r ? Theme.primary.opacity(0.10) : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func icon(_ name: String, tint: Color, filled: Bool = false) -> some View {
        ZStack {
            Circle().fill(filled ? Theme.primary : Theme.primary.opacity(0.12)).frame(width: 34, height: 34)
            Image(systemName: name).font(.subheadline.weight(.semibold)).foregroundStyle(tint)
        }
    }
}
