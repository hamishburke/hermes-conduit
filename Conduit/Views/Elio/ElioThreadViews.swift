#if ELIO_PERSONAL
import SwiftUI

private let elioBubbleRadius: CGFloat = 20

/// What width a message actually needs. `MarkdownText` fills whatever it is
/// given, so a bubble has to be told its own width or every bubble comes out
/// the same size. Plain text is measured in the renderer's body font; a
/// message with block structure (code, lists, tables, headings) takes the
/// full cap, because a measurement of its source would undershoot the block.
enum ElioTextMeasure {
    /// Measured widths, keyed by cap, type size and source. A streaming reply
    /// re-asks once per token; a settled message hits this every redraw.
    private static var cache: [String: CGFloat] = [:]
    private static var insertionOrder: [String] = []
    private static let cacheLimit = 800

    static func width(of source: String, cap: CGFloat, cacheable: Bool = true) -> CGFloat {
        guard cap > 60 else { return cap }
        let size = ChatTypography.stored()
        let font = ChatTypography.font(for: .body, chatSize: size)
        let key = "\(Int(cap))|\(Int(font.pointSize))|\(source)"
        if cacheable, let hit = cache[key] { return hit }
        let value = measure(source, cap: cap, font: font)
        guard cacheable else { return value }
        if insertionOrder.count >= cacheLimit {
            cache.removeValue(forKey: insertionOrder.removeFirst())
        }
        cache[key] = value
        insertionOrder.append(key)
        return value
    }

    private static func measure(_ source: String, cap: CGFloat, font: UIFont) -> CGFloat {
        guard !hasBlock(source) else { return cap }
        let plain = source
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "~~", with: "")
        let rect = (plain as NSString).boundingRect(
            with: CGSize(width: cap, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        // 28 points of bubble padding plus two of rounding.
        return min(cap, ceil(rect.width) + 30)
    }

    private static func hasBlock(_ source: String) -> Bool {
        let lines = "\n" + source
        return source.contains("```") || lines.contains("\n#") || lines.contains("\n- ")
            || lines.contains("\n* ") || lines.contains("\n|") || lines.contains("\n> ")
            || lines.contains("\n1.")
    }
}

/// The thread's own width, so a bubble knows where its edge is.
struct ElioWidthKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}


/// A press that sinks under the finger and springs back, for choices and the
/// send arrow.
struct ElioPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

/// A message bubble: blue and right-aligned when Hamish sent it, system grey
/// and left-aligned when Elio did. Every bubble rounds the same way, as the
/// reference thread does. A long press sinks it under the finger and offers
/// the system's reactions, which is the only gesture a bubble has.
struct ElioBubble: View {
    let row: ElioRow
    /// Asked only when a finger lands, never while drawing.
    var canReact: () -> Bool = { false }
    /// DEBUG look build only: open the reaction picker so it can be
    /// photographed, since a long press cannot be sent to a headless simulator.
    var startsWithPicker = false
    var onReact: (String) -> Void = { _ in }
    @State private var pressing = false
    @State private var picking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isUser: Bool { row.kind == .user }

    private var width: CGFloat {
        row.width > 0 ? row.width : 240
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                bubble
                    .scaleEffect(pressing ? 0.97 : 1)
                    .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.72),
                               value: pressing)
                    .onLongPressGesture(minimumDuration: 0.3, maximumDistance: 24) {
                        guard canReact() else { return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            picking = true
                        }
                    } onPressingChanged: { down in
                        pressing = down
                    }
                if !row.reactions.isEmpty { reactions }
            }
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            .overlay(alignment: isUser ? .topTrailing : .topLeading) {
                if picking { picker.offset(y: -48) }
            }
        }
        .padding(.top, row.groupStart ? 12 : 4)
        .onAppear {
            if startsWithPicker {
                picking = true
                return
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: picking)
        .onChange(of: picking) { _, isOpen in
            guard isOpen, !startsWithPicker else { return }
            Task {
                try? await Task.sleep(for: .seconds(4))
                withAnimation(.easeOut(duration: 0.15)) { picking = false }
            }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 5) {
            if !row.text.isEmpty {
                if isUser {
                    MarkdownText(source: row.text, foregroundStyle: .white,
                                 usesAccentSurface: true)
                } else {
                    MarkdownText(source: row.text, isStreaming: row.isStreaming)
                }
            }
            if row.attachments > 0 {
                Label(attachmentWords, systemImage: "paperclip")
                    .font(.caption)
                    .foregroundStyle(isUser ? .white.opacity(0.85) : .secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: elioBubbleRadius, style: .continuous)
                .fill(isUser ? Color(uiColor: .systemBlue)
                      : Color(uiColor: .secondarySystemBackground))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spoken))
        .accessibilityHint(Text(verbatim: "Hold to react"))
    }

    private var reactions: some View {
        var seen: Set<String> = []
        let emoji = row.reactions.map(\.emoji).filter { seen.insert($0).inserted }
        return Text(verbatim: emoji.joined())
            .font(.system(size: 13))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Color(uiColor: .secondarySystemBackground))
            )
            .overlay(
                Capsule().strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
            )
    }

    private var picker: some View {
        HStack(spacing: 0) {
            ForEach(MessageReaction.tapbacks, id: \.self) { emoji in
                Button {
                    picking = false
                    onReact(emoji)
                } label: {
                    Text(emoji)
                        .font(.system(size: 24))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(ElioPressStyle())
                .accessibilityLabel(Text(verbatim: "React \(emoji)"))
            }
        }
        .padding(.horizontal, 6)
        .conduitGlassSurface(cornerRadius: 24, interactive: true)
        .transition(.scale(scale: 0.85, anchor: isUser ? .topTrailing : .topLeading)
            .combined(with: .opacity))
    }

    private var spoken: String {
        let prefix = isUser ? "You said: " : "Elio said: "
        let words = row.text.isEmpty ? attachmentWords : row.text
        return prefix + words
    }

    private var attachmentWords: String {
        row.attachments == 1 ? "1 attachment" : "\(row.attachments) attachments"
    }
}

/// The three-dot bubble. It stops under Reduce Motion, where the dots are
/// simply present.
struct ElioTypingBubble: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .frame(width: 7, height: 7)
                            .foregroundStyle(Color(uiColor: .tertiaryLabel))
                            .opacity(reduceMotion ? 0.6 : opacity(time, index))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: elioBubbleRadius, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .accessibilityLabel(Text(verbatim: "Elio is typing"))
    }

    private func opacity(_ time: TimeInterval, _ index: Int) -> Double {
        let phase = time * 2.2 - Double(index) * 0.7
        return 0.25 + 0.75 * (0.5 + 0.5 * sin(phase))
    }
}

/// A question from Elio, drawn as a message with its answers as messages
/// under it. A clarify that cannot be answered strands the turn.
struct ElioClarifyCard: View {
    let row: ElioRow
    var onAnswer: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(row.clarify?.questions ?? []) { question in
                bubble(Text(verbatim: question.question))
                if let answer = question.answer, !answer.isEmpty {
                    bubble(Text(verbatim: answer))
                        .foregroundStyle(.secondary)
                } else if question.isAnswerable, !question.isFreeText {
                    ForEach(question.choices) { choice in
                        Button {
                            onAnswer(question.id, choice.value)
                        } label: {
                            bubble(Text(verbatim: choice.label))
                        }
                        .buttonStyle(ElioPressStyle())
                        .disabled(question.status == .submitting || question.status == .expired)
                    }
                } else if question.isAnswerable {
                    bubble(Text(verbatim: "Type your answer below.")
                            .foregroundStyle(.secondary))
                }
            }
        }
        .padding(.top, 12)
    }

    private func bubble(_ text: Text) -> some View {
        HStack(spacing: 0) {
            text
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: elioBubbleRadius, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
            Spacer(minLength: 40)
        }
    }
}

/// A command that needs a decision: its choices while it is pending or
/// failed, and its outcome once it is settled.
struct ElioApprovalCard: View {
    let row: ElioRow
    var onAnswer: (String) -> Void

    private var approval: ApprovalActivity? { row.approval }

    private var choices: [String] {
        guard let approval else { return [] }
        return approval.choices ?? (approval.smartDenied ? ["once", "deny"]
                                    : ["once", "session", "always", "deny"])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let approval {
                bubble(Text(verbatim: approval.description.isEmpty
                            ? approval.command : approval.description))
                if approval.status == .pending || approval.status == .error {
                    ForEach(choices, id: \.self) { choice in
                        if choice != "always" || approval.allowPermanent {
                            Button {
                                onAnswer(choice)
                            } label: {
                                bubble(Text(verbatim: approvalLabel(choice)))
                            }
                            .buttonStyle(ElioPressStyle())
                        }
                    }
                } else {
                    bubble(Text(verbatim: approvalOutcome(approval)))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 12)
    }

    private func bubble(_ text: Text) -> some View {
        HStack(spacing: 0) {
            text
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: elioBubbleRadius, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
            Spacer(minLength: 40)
        }
    }

    private func approvalLabel(_ choice: String) -> String {
        switch choice {
        case "once": return "Allow once"
        case "session": return "Allow for this session"
        case "always": return "Always allow"
        case "deny": return "Deny"
        default: return choice
        }
    }

    private func approvalOutcome(_ approval: ApprovalActivity) -> String {
        switch approval.choice {
        case "once": return "Allowed once"
        case "session": return "Allowed for this session"
        case "always": return "Always allowed"
        case "deny": return "Denied"
        default:
            switch approval.status {
            case .approved: return "Allowed"
            case .rejected: return "Denied"
            case .expired: return "Expired"
            default: return "Waiting"
            }
        }
    }
}
#endif
