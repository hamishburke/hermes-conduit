#if ELIO_PERSONAL
import SwiftUI

private let elioBubbleRadius: CGFloat = 20

/// A message bubble: blue and right-aligned when Hamish sent it, system grey
/// and left-aligned when Elio did. Every bubble rounds the same way, as the
/// reference thread does.
struct ElioBubble: View {
    let row: ElioRow

    private var isUser: Bool { row.kind == .user }

    var body: some View {
        HStack(spacing: 0) {
            if isUser { Spacer(minLength: 56) }
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
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: elioBubbleRadius, style: .continuous)
                    .fill(isUser ? Color(uiColor: .systemBlue)
                          : Color(uiColor: .secondarySystemBackground))
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: spoken))
            if !isUser { Spacer(minLength: 0) }
        }
        .padding(.top, row.groupStart ? 8 : 3)
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
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: elioBubbleRadius, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
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
                        .buttonStyle(.plain)
                        .disabled(question.status == .submitting || question.status == .expired)
                    }
                } else if question.isAnswerable {
                    bubble(Text(verbatim: "Type your answer below.")
                            .foregroundStyle(.secondary))
                }
            }
        }
        .padding(.top, 8)
    }

    private func bubble(_ text: Text) -> some View {
        HStack(spacing: 0) {
            text
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
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
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    bubble(Text(verbatim: approvalOutcome(approval)))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 8)
    }

    private func bubble(_ text: Text) -> some View {
        HStack(spacing: 0) {
            text
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
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
