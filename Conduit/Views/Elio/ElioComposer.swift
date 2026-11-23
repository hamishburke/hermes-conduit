#if ELIO_PERSONAL
import SwiftUI

/// One field on Liquid Glass with a microphone on its leading edge and a send
/// arrow on its trailing one. Dictation writes into the draft and never sends:
/// it is the same service the full composer uses, so its engine choice, custom
/// words and audio-session handling all still apply.
struct ElioComposer: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var prompt: String = "Message Elio"
    var onSend: () -> Void
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var dictation = ComposerDictationService()
    @State private var dictationPrefix = ""
    @State private var sends = 0

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isDictating: Bool {
        dictation.isDictating || dictation.isStarting || dictation.isTranscribing
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
        .padding(.vertical, 12)
        .frame(minHeight: 48)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .simultaneousGesture(TapGesture().onEnded { focused.wrappedValue = true })
        .conduitGlassSurface(cornerRadius: 24, interactive: true)
        .overlay(alignment: .bottomTrailing) {
            if canSend {
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
                .accessibilityLabel(Text(verbatim: "Send"))
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            } else {
                Button(action: toggleDictation) {
                    Image(systemName: isDictating ? "stop.fill" : "mic.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isDictating ? Color(uiColor: .systemRed) : Color.primary)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .buttonStyle(ElioPressStyle())
                .padding(.trailing, 6)
                .padding(.bottom, 5)
                .accessibilityLabel(Text(verbatim: isDictating ? "Stop dictation" : "Dictate"))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: canSend)
        .sensoryFeedback(.impact(weight: .light), trigger: sends)
        .sensoryFeedback(.impact(weight: .medium), trigger: isDictating)
    }

    private func toggleDictation() {
        if dictation.isDictating || dictation.isStarting {
            dictation.stop()
            return
        }
        guard let token = dictation.reserveStart() else { return }
        dictationPrefix = text
        dictation.onTranscript = { transcript in
            text = ComposerDictation.draft(before: dictationPrefix, dictated: transcript)
        }
        dictation.onFailure = { _ in }
        dictation.onFinish = { _ in }
        Task {
            try? await dictation.start(token: token,
                                       hermesGateway: { appState.makeVoiceGateway() })
        }
    }
}
#endif
