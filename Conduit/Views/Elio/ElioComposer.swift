#if ELIO_PERSONAL
import SwiftUI

/// One field with its send arrow inside it, the way Messages draws one.
/// The arrow fades in, so the field never changes width as typing starts.
struct ElioComposer: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var prompt: String = "Message"
    var onSend: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .padding(.leading, 14)
        .padding(.trailing, 44)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(uiColor: .separator).opacity(0.4))
        )
        .overlay(alignment: .bottomTrailing) {
            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color(uiColor: .conduitUserBubble)))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 5)
            .padding(.bottom, 4)
            .opacity(canSend ? 1 : 0)
            .disabled(!canSend)
            .accessibilityHidden(!canSend)
            .accessibilityLabel(Text(verbatim: "Send"))
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: canSend)
    }
}
#endif
