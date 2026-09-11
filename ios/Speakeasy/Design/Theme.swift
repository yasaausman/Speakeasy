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
    // Grounds & surfaces (Playful & Vibrant)
    static let ground = Color.cool(0xF4F7F6, 0x1A1C19)       // Very soft mint/gray tint
    static let surface = Color.cool(0xFFFFFF, 0x2A2D2A)      // Pure white cards
    static let surfaceSunk = Color.cool(0xE8ECEB, 0x141513)

    // Ink (Friendly, not pure black)
    static let ink = Color.cool(0x2D3748, 0xF7FAFC)
    static let inkSecondary = Color.cool(0x718096, 0xA0AEC0)

    // Brand - Vibrant, friendly primary colors (like Duolingo's green/blue/orange)
    static let primary = Color.cool(0x1CB0F6, 0x1CB0F6)      // Friendly Sky Blue
    static let primaryDeep = Color.cool(0x1899D6, 0x1899D6)
    static let accent = Color.cool(0xFF9600, 0xFF9600)       // Playful Orange
    static let success = Color.cool(0x58CC02, 0x58CC02)      // Bouncy Green

    // Lines
    static let hairline = Color.cool(0xE2E8F0, 0x4A5568)

    enum Space { static let xs: CGFloat = 8, s: CGFloat = 16, m: CGFloat = 24, l: CGFloat = 32, xl: CGFloat = 48 }
    enum Radius { static let card: CGFloat = 32, chip: CGFloat = 20 }
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
