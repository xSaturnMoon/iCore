import SwiftUI

// MARK: - Color Hex
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4 & 0xF)*17,(int & 0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8 & 0xFF,int & 0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16 & 0xFF,int>>8 & 0xFF,int & 0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255,
                  blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Glass Card
struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(hex: "13132A"))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "3A3A60").opacity(0.8), Color(hex: "2A2A44").opacity(0.4)],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1)
            )
    }
}

// MARK: - Pulsing Glow
struct PulsingGlow: ViewModifier {
    let color: Color
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(on ? 0.85 : 0.2), radius: on ? 14 : 4)
            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

extension View {
    func glassCard() -> some View { modifier(GlassCard()) }
    func pulsingGlow(color: Color) -> some View { modifier(PulsingGlow(color: color)) }
}
