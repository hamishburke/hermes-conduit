#if ELIO_PERSONAL
import SwiftUI

/// One row of the personal thread. Built from AppState's transcript, never
/// from ChatView's `TranscriptRow`: the personal surface owns its own model.
struct ElioRow: Identifiable, Equatable {
    enum Kind: Equatable {
        case user
        case agent
        case clarify
        case approval
    }

    let id: String
    let kind: Kind
    var text: String
    var clarify: ClarifyActivity?
    var approval: ApprovalActivity?
    var attachments: Int = 0
    var isStreaming = false
    var groupStart = true

    static func build(_ messages: [ChatMessage], streaming: String) -> [ElioRow] {
        var rows: [ElioRow] = []
        for message in messages {
            guard let row = row(for: message) else { continue }
            rows.append(row)
        }
        if !streaming.isEmpty {
            var tail = ElioRow(id: "elio-streaming", kind: .agent, text: streaming)
            tail.isStreaming = true
            rows.append(tail)
        }
        group(&rows)
        return rows
    }

    private static func row(for message: ChatMessage) -> ElioRow? {
        switch message.role {
        case .user:
            let attachments = message.attachments?.count ?? 0
            guard !message.content.isEmpty || attachments > 0 else { return nil }
            return ElioRow(id: message.id, kind: .user, text: message.content,
                           attachments: attachments)
        case .assistant, .partial, .clarify:
            if let clarify = message.clarify, !clarify.questions.isEmpty {
                return ElioRow(id: message.id, kind: .clarify, text: message.content,
                               clarify: clarify)
            }
            if let approval = message.approval {
                return ElioRow(id: message.id, kind: .approval, text: message.content,
                               approval: approval)
            }
            guard !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }
            return ElioRow(id: message.id, kind: .agent, text: message.content)
        case .approval:
            guard let approval = message.approval else { return nil }
            return ElioRow(id: message.id, kind: .approval, text: message.content,
                           approval: approval)
        case .system, .tool, .reasoning, .inputPrompt, .connection:
            // Working notes stay out of a person-shaped thread.
            return nil
        }
    }

    /// Consecutive messages from one speaker sit closer together, as they do
    /// in Messages. Every bubble keeps the same rounding.
    private static func group(_ rows: inout [ElioRow]) {
        for index in rows.indices {
            guard rows[index].kind == .user || rows[index].kind == .agent else { continue }
            if index > 0, rows[index - 1].kind == rows[index].kind {
                rows[index].groupStart = false
            }
        }
    }
}
#endif
