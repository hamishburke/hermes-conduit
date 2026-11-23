#if ELIO_PERSONAL
import SwiftUI

/// One field on Liquid Glass, with its send arrow inside it. The arrow fades
/// in, so the field never changes width as typing starts.
struct ElioComposer: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var prompt: String = "Message Elio"
    var onSend: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sends = 0

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        TextField(text: $text, prompt: Text(verbatim: prompt), axis: .vertical) {
            EmptyView()
        }
        .textFieldStyle(.plain)
        .lineLimit(1...6)
        .focused(focused)
        .padding(.leading, 16)
        .padding(.trailing, 46)
        .padding(.vertical, 11)
        .conduitGlassSurface(cornerRadius: 24, interactive: true)
        .overlay(alignment: .bottomTrailing) {
            Button {
                sends += 1
                onSend()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color(uiColor: .systemBlue)))
            }
            .buttonStyle(ElioPressStyle())
            .padding(.trailing, 6)
            .padding(.bottom, 5)
            .opacity(canSend ? 1 : 0)
            .disabled(!canSend)
            .accessibilityHidden(!canSend)
            .accessibilityLabel(Text(verbatim: "Send"))
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: canSend)
        .sensoryFeedback(.impact(weight: .light), trigger: sends)
    }
}
#endif
