import SwiftUI

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var color: Color
    var rotation: Double
    var scale: CGFloat
    var speed: Double
}

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isAnimating = false

    let colors: [Color] = [Theme.primary, Theme.accent, Theme.success, .yellow, .pink, .purple]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Rectangle()
                        .fill(p.color)
                        .frame(width: 8 * p.scale, height: 16 * p.scale)
                        .rotationEffect(.degrees(isAnimating ? p.rotation + 360 : p.rotation))
                        .position(x: p.x, y: isAnimating ? geo.size.height + 50 : p.y)
                        .opacity(isAnimating ? 0 : 1)
                        .animation(
                            .timingCurve(0.4, 0.0, 0.2, 1.0, duration: p.speed)
                            .delay(Double.random(in: 0...0.5)),
                            value: isAnimating
                        )
                }
            }
            .onAppear {
                generateParticles(in: geo.size)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isAnimating = true
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func generateParticles(in size: CGSize) {
        var newParticles: [ConfettiParticle] = []
        for _ in 0..<80 {
            let p = ConfettiParticle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: -size.height/2...0), // Start above screen
                color: colors.randomElement()!,
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.5...1.5),
                speed: Double.random(in: 2.0...4.0)
            )
            newParticles.append(p)
        }
        particles = newParticles
    }
}
