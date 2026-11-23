#if ELIO_PERSONAL
import SwiftUI

/// Elio's conversation, drawn as one native thread. AppState stays the
/// engine: it opens the chat, sends, streams and answers decisions. This
/// screen owns the whole presentation, so none of Conduit's chat chrome
/// reaches it.
struct ElioChatScreen: View {
    @EnvironmentObject private var appState: AppState
    let onOpenSettings: () -> Void
    /// Sample rows for the DEBUG look build. Nil on every real launch.
    var previewRows: [ElioRow]? = nil
    @State private var following = true
    @SceneStorage("elio.composer.draft") private var draft = ""
    @FocusState private var composerFocused: Bool

    private let bottomID = "elio-bottom"

    private var rows: [ElioRow] {
        previewRows ?? ElioRow.build(appState.messages, streaming: appState.streamingText)
    }

    private var showsTyping: Bool {
        previewRows == nil && appState.turnState.isRunning && appState.streamingText.isEmpty
    }

    /// The last message Hamish sent, once Elio has answered it or is working
    /// on it. "Seen" here means Hermes started its turn, not a delivery
    /// receipt this app invented.
    private var seenRowID: String? {
        guard let index = rows.lastIndex(where: { $0.kind == .user }) else { return nil }
        if index < rows.count - 1 { return rows[index].id }
        guard previewRows == nil, appState.turnState.isRunning else { return nil }
        return rows[index].id
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                tracked(
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(rows) { row in
                                rowView(row)
                            }
                            if showsTyping {
                                ElioTypingBubble()
                                    .transition(.opacity)
                            }
                            Color.clear
                                .frame(height: 1)
                                .id(bottomID)
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)
                        .animation(.easeOut(duration: 0.2), value: showsTyping)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .defaultScrollAnchor(.bottom)
                )
                .safeAreaInset(edge: .bottom, spacing: 0) { composerBar }
                .onAppear { scrollToBottom(proxy, animated: false) }
                .onChange(of: rows.last?.id) { _, _ in scrollToBottom(proxy, animated: true) }
                .onChange(of: appState.streamingText) { _, _ in scrollToBottom(proxy, animated: false) }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button(action: onOpenSettings) {
                        Text(verbatim: "Elio")
                            .font(.headline)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text(verbatim: "Opens settings"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.startNewChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .disabled(previewRows == nil && !appState.canTapNewChat)
                    .accessibilityLabel(Text(verbatim: "New chat"))
                }
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: ElioRow) -> some View {
        Group {
            switch row.kind {
            case .user, .agent:
                ElioBubble(row: row)
                if row.id == seenRowID {
                    Text(verbatim: "Seen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 2)
                        .padding(.trailing, 2)
                }
            case .clarify:
                ElioClarifyCard(row: row) { questionId, answer in
                    guard let requestId = row.clarify?.requestId else { return }
                    Task {
                        await appState.respondToClarify(requestId: requestId,
                                                       questionId: questionId,
                                                       answer: answer)
                    }
                }
            case .approval:
                ElioApprovalCard(row: row) { choice in
                    guard let approval = row.approval else { return }
                    Task {
                        await appState.respondToApproval(messageId: row.id,
                                                         choice: choice,
                                                         shown: approval)
                    }
                }
            }
        }
        .id(row.id)
    }

    private var composerBar: some View {
        VStack(spacing: 6) {
            if let status {
                Text(verbatim: status)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            ElioComposer(text: $draft, focused: $composerFocused,
                         prompt: pendingFreeTextQuestion() == nil ? "Message Elio" : "Answer Elio",
                         onSend: send)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(.bar)
    }

    private var status: String? {
        // The look build has no connection to report.
        guard previewRows == nil else { return nil }
        if let error = appState.errorMessage, !error.isEmpty { return error }
        if !appState.isConnected { return "Offline" }
        return nil
    }

    /// Sits the thread at its last message and keeps it there while a reply
    /// streams, unless the person has scrolled up to read.
    @ViewBuilder
    private func tracked<V: View>(_ view: V) -> some View {
        if #available(iOS 18.0, *) {
            view.onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.containerSize.height
                    >= geometry.contentSize.height - 140
            } action: { _, pinned in
                following = pinned
            }
        } else {
            view
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        guard following else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(bottomID, anchor: .bottom)
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let pending = pendingFreeTextQuestion() {
            draft = ""
            Task {
                await appState.respondToClarify(requestId: pending.requestId,
                                               questionId: pending.questionId,
                                               answer: text)
            }
            return
        }
        draft = ""
        following = true
        Task {
            let sent = await appState.sendMessage(text)
            if !sent, draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft = text
            }
        }
    }

    /// A question that wants words rather than a tap: the composer answers
    /// it instead of starting a new turn.
    private func pendingFreeTextQuestion() -> (requestId: String, questionId: String)? {
        for message in appState.messages.reversed() {
            guard let clarify = message.clarify, !clarify.isExpired else { continue }
            for question in clarify.questions
            where question.isAnswerable && question.isFreeText {
                return (clarify.requestId, question.id)
            }
            return nil
        }
        return nil
    }
}
#endif
