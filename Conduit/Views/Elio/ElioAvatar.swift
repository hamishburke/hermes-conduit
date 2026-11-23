#if ELIO_PERSONAL
import SwiftUI

/// Elio in the bar: the persona's own artwork, with the state of the work
/// showing on it. Idle is the plain face; working is a slow ring breathing
/// outwards; needing him is a dot in the corner.
struct ElioAvatar: View {
    enum State: Equatable {
        case idle
        case working
        case needsYou
        case finished
    }

    let asset: String
    var state: State = .idle
    var size: CGFloat = 34
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    private var badgeColor: Color? {
        switch state {
        case .needsYou: return .orange
        case .finished: return Color(uiColor: .systemGreen)
        case .idle, .working: return nil
        }
    }

    var body: some View {
        ZStack {
            if state == .working {
                Circle()
                    .strokeBorder(Color(uiColor: .systemBlue), lineWidth: 2.5)
                    .frame(width: size + 6, height: size + 6)
                    .opacity(breathing ? 1 : 0.35)
            }
            Image(asset)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
            if let badgeColor {
                Circle()
                    .fill(badgeColor)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().strokeBorder(Color(uiColor: .systemBackground), lineWidth: 2))
                    .offset(x: size / 2 - 4, y: size / 2 - 4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: size + 10, height: size + 10)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state)
        .onAppear(perform: breathe)
        .onChange(of: state) { _, _ in breathe() }
    }

    private func breathe() {
        breathing = false
        guard state == .working, !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            breathing = true
        }
    }
}
#endif
