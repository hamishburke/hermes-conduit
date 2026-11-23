#if ELIO_PERSONAL
import SwiftUI

/// A message bubble drawn from system colours and system type. The bar and
/// composer around it are the system's own; nothing in the thread is custom
/// chrome from the wider app.
struct ElioBubble: View {
    let row: ElioRow

    private var isUser: Bool { row.kind == .user }
    private let radius: CGFloat = 19
    private let tail: CGFloat = 5

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: radius,
            bottomLeadingRadius: isUser || !row.groupEnd ? radius : tail,
            bottomTrailingRadius: !isUser || !row.groupEnd ? radius : tail,
            topTrailingRadius: radius,
            style: .continuous
        )
    }

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
            .background(shape.fill(isUser ? Color(uiColor: .conduitUserBubble) : Color(uiColor: .secondarySystemBackground)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: spoken))
            if !isUser { Spacer(minLength: 0) }
        }
        .padding(.top, row.groupStart ? 10 : 2)
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
                UnevenRoundedRectangle(topLeadingRadius: 19, bottomLeadingRadius: 5,
                                       bottomTrailingRadius: 19, topTrailingRadius: 19,
                                       style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            Spacer(minLength: 56)
        }
        .padding(.top, 10)
        .accessibilityLabel(Text(verbatim: "Elio is typing"))
    }

    private func opacity(_ time: TimeInterval, _ index: Int) -> Double {
        let phase = time * 2.2 - Double(index) * 0.7
        return 0.25 + 0.75 * (0.5 + 0.5 * sin(phase))
    }
}

/// A question from Elio, answered with a tap. A clarify that cannot be
/// answered strands the turn, so it is drawn as a decision rather than prose.
struct ElioClarifyCard: View {
    let row: ElioRow
    var onAnswer: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(row.clarify?.questions ?? []) { question in
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: question.question)
                        .font(.body)
                    if let answer = question.answer, !answer.isEmpty {
                        Text(verbatim: answer)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if question.isAnswerable, !question.isFreeText {
                        ForEach(question.choices) { choice in
                            Button {
                                onAnswer(question.id, choice.value)
                            } label: {
                                Text(verbatim: choice.label)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 11)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color(uiColor: .tertiarySystemFill))
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(question.status == .submitting || question.status == .expired)
                        }
                    } else if question.isAnswerable {
                        Text(verbatim: "Type your answer below.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .padding(.trailing, 40)
        .padding(.top, 10)
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
        VStack(alignment: .leading, spacing: 12) {
            if let approval {
                Text(verbatim: approval.description.isEmpty ? approval.command : approval.description)
                    .font(.body)
                if approval.status == .pending || approval.status == .error {
                    ForEach(choices, id: \.self) { choice in
                        if choice != "always" || approval.allowPermanent {
                            Button {
                                onAnswer(choice)
                            } label: {
                                Text(verbatim: approvalLabel(choice))
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 11)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color(uiColor: .tertiarySystemFill))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Text(verbatim: approvalOutcome(approval))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .padding(.trailing, 40)
        .padding(.top, 10)
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
