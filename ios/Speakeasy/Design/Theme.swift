import SwiftUI

/*
 DIRECTION CONTRACT — Speakeasy visual world (seed: warm-human, user-pinned)
 THESIS: A caring companion that makes the scary English phone call for you. It
   refuses the cold utility-app look for something warm, human, and reassuring.
 OWN-WORLD: warm cream / charcoal grounds, SF Rounded throughout, ONE coral tint
   with a honey accent, big soft-shadowed cards, a living coral "voice orb" that
   breathes. No neutral gray chrome; brand lives in warmth and roundness.
 STORY: the user feels safe to speak → trusts the read-back → watches the call →
   hears the outcome in their own language.
 FIRST VIEWPORT: calm cream screen, generous space, a large glowing coral orb
   centered as the invitation to speak, a friendly prompt, a soft input below;
   language pill top-right.
 FORM: warm humane companion app (pinned by the user over the concept roll).
 FINISH: unreviewed and undocumented is unfinished; this build ends with the
   finish review, the verdict, DESIGN.md, and every shipping raster carrying its
   provenance.
*/

// MARK: - Color helpers (warm palette, adapts to Dark Mode)

extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
    /// A color that resolves differently in light vs dark appearance.
    static func warm(_ light: UInt, _ dark: UInt) -> Color {
        Color(uiColor: UIColor { trait in
            UIColor(Color(hex: trait.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

enum Theme {
    // Grounds & surfaces
    static let ground = Color.warm(0xF5EDE1, 0x191512)
    static let surface = Color.warm(0xFFFDF8, 0x241E19)
    static let surfaceSunk = Color.warm(0xF0E7D8, 0x2C251E)

    // Ink
    static let ink = Color.warm(0x2B2723, 0xF4ECE0)
    static let inkSecondary = Color.warm(0x6E655B, 0xB2A798)

    // Brand
    static let primary = Color.warm(0xE15E43, 0xF47C61)      // coral — the one tint
    static let primaryDeep = Color.warm(0xC64E36, 0xEF6A4E)
    static let honey = Color.warm(0xD98A24, 0xF0B152)        // warm accent (highlights only)
    static let success = Color.warm(0x2F8F5F, 0x59C48D)

    // Lines
    static let hairline = Color.warm(0xE7DCCB, 0x362E27)

    enum Space { static let xs: CGFloat = 6, s: CGFloat = 12, m: CGFloat = 18, l: CGFloat = 26, xl: CGFloat = 40 }
    enum Radius { static let card: CGFloat = 24, chip: CGFloat = 14 }
}

// MARK: - Soft card

private struct SoftCard: ViewModifier {
    var fill: Color
    var strokeColor: Color
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).strokeBorder(strokeColor, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}

extension View {
    func softCard(_ fill: Color = Theme.surface, stroke: Color = Theme.hairline) -> some View {
        modifier(SoftCard(fill: fill, strokeColor: stroke))
    }
}

// MARK: - Pill buttons

struct PrimaryPill: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .padding(.horizontal, 28)
            .frame(minHeight: 52)
            .background(Capsule().fill(Theme.primary))
            .shadow(color: Theme.primary.opacity(0.35), radius: 14, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SoftPill: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.ink)
            .padding(.vertical, 15)
            .padding(.horizontal, 26)
            .frame(minHeight: 52)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
