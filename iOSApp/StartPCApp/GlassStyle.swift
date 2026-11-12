import SwiftUI

/// Liquid Glass helpers (iOS 26+) z bezpiecznym fallbackiem.
struct GlassBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.12, blue: 0.28),
                    Color(red: 0.12, green: 0.28, blue: 0.42),
                    Color(red: 0.22, green: 0.18, blue: 0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.cyan.opacity(0.35))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: -120, y: -220)

            Circle()
                .fill(Color.indigo.opacity(0.40))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: 140, y: 180)

            Circle()
                .fill(Color.teal.opacity(0.25))
                .frame(width: 220, height: 220)
                .blur(radius: 50)
                .offset(x: 40, y: -40)
        }
        .ignoresSafeArea()
    }
}

extension View {
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat = 24, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            if interactive {
                self.glassEffect(.regular.interactive(), in: shape)
            } else {
                self.glassEffect(.regular, in: shape)
            }
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    func liquidGlassButton() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func liquidGlassProminentButton() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 24
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: cornerRadius)
    }
}
