import SwiftUI

/*
 DIRECTION CONTRACT — Speakeasy visual world (seed: calm-blue, user-pinned)
 THESIS: A calm, trustworthy companion that makes the scary English phone call
   for you. Cool and reassuring, not a cold utility app — confidence you can hand
   your worry to.
 OWN-WORLD: cool blue-gray grounds (no beige), SF Rounded throughout, ONE blue
   tint with a teal accent for highlights, big soft-shadowed cards, a living blue
   "voice orb" that breathes. Brand lives in calm and roundness.
 STORY: the user feels safe to speak → trusts the read-back → watches the call
   unfold live → hears the outcome in their own language, and it's saved.
 FIRST VIEWPORT: calm cool screen, generous space, a large glowing blue orb
   centered as the invitation to speak, a friendly prompt, a soft input; a burger
   menu top-left, language pill top-right.
 FORM: calm humane companion app (blue pinned by the user over the warm world).
 FINISH: unreviewed and undocumented is unfinished; this build ends with the
   finish review, the verdict, DESIGN.md, and every shipping raster carrying its
   provenance.
*/

// MARK: - Color helpers (cool blue palette, adapts to Dark Mode)

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
    static func cool(_ light: UInt, _ dark: UInt) -> Color {
        Color(uiColor: UIColor { trait in
            UIColor(Color(hex: trait.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

enum Theme {
    // Grounds & surfaces (cool blue-gray, never beige)
    static let ground = Color.cool(0xEDF1F7, 0x0E1420)
    static let surface = Color.cool(0xFCFDFF, 0x18202E)
    static let surfaceSunk = Color.cool(0xE3EAF3, 0x1E2838)

    // Ink (cool slate)
    static let ink = Color.cool(0x1B2430, 0xE9EEF6)
    static let inkSecondary = Color.cool(0x5B6675, 0x94A2B6)

    // Brand
    static let primary = Color.cool(0x2F6FE4, 0x5B8DEF)      // blue — the one tint
    static let primaryDeep = Color.cool(0x2559C0, 0x4A7CE0)
    static let accent = Color.cool(0x0E97A6, 0x2CC5CE)       // teal — highlights only
    static let success = Color.cool(0x1E9A66, 0x4FC48A)

    // Lines
    static let hairline = Color.cool(0xDCE4EE, 0x263349)

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
            .shadow(color: Color.black.opacity(0.07), radius: 18, x: 0, y: 10)
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
