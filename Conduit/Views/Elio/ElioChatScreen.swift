#if ELIO_PERSONAL
import SwiftUI

/// Elio's conversation, drawn as one native thread. AppState stays the
/// engine: it opens the chat, sends, streams and answers decisions. This
/// screen owns the whole presentation, so none of Conduit's chat chrome
/// reaches it.
struct ElioChatScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    let onOpenSettings: () -> Void
    /// Sample rows for the DEBUG look build. Nil on every real launch.
    var previewRows: [ElioRow]? = nil
    /// DEBUG look build only: open the first reaction picker.
    var previewPicksReaction = false
    /// DEBUG look build only: force the persona's state for a screenshot.
    var previewState: ElioAvatar.State? = nil
    @State private var following = true
    @State private var threadWidth: CGFloat = 0
    @State private var showsChats = ProcessInfo.processInfo.arguments.contains("-ElioLookChats")
    @SceneStorage private var draft: String
    let draftSessionID: String?
    let draftScope: String

    init(onOpenSettings: @escaping () -> Void, previewRows: [ElioRow]? = nil,
         previewPicksReaction: Bool = false, previewState: ElioAvatar.State? = nil,
         draftSessionID: String? = nil, draftScope: String = "preview") {
        self.onOpenSettings = onOpenSettings
        self.previewRows = previewRows
        self.previewPicksReaction = previewPicksReaction
        self.previewState = previewState
        self.draftSessionID = draftSessionID
        self.draftScope = draftScope
        _draft = SceneStorage(wrappedValue: "", "elio.composer.draft." + draftScope)
    }
    @FocusState private var composerFocused: Bool

    private let bottomID = "elio-bottom"

    /// A bubble may run to within 64 points of the far edge, as a message
    /// does in Messages, and no further.
    private var bubbleCap: CGFloat {
        max(180, threadWidth - 64)
    }

    private var rows: [ElioRow] {
        previewRows ?? ElioRow.build(transcript,
                                     streaming: appState.streamingText,
                                     cap: bubbleCap)
    }

    /// The live transcript, or the saved copy of it while the connection is
    /// still being reached. Never a mix: Hermes' rows take over whole.
    private var transcript: [ChatMessage] {
        let live = appState.messages
        if !live.isEmpty { return live }
        return appState.offlineChatPresentation?.displayedMessages ?? []
    }

    private var showsTyping: Bool {
        previewRows == nil && appState.turnState.isRunning && appState.streamingText.isEmpty
    }

    /// The last message Hamish sent, once Elio has answered it or is working
    /// on it. "Seen" here means Hermes started its turn, not a delivery
    /// receipt this app invented.
    private func seenRowID(in rows: [ElioRow]) -> String? {
        guard let index = rows.lastIndex(where: { $0.kind == .user }) else { return nil }
        if index < rows.count - 1 { return rows[index].id }
        guard previewRows == nil, appState.turnState.isRunning else { return nil }
        return rows[index].id
    }

    var body: some View {
        let rows = self.rows
        let seen = seenRowID(in: rows)
        let pickerRow = previewPicksReaction ? rows.last(where: { $0.kind == .agent })?.id : nil
        NavigationStack {
            ScrollViewReader { proxy in
                tracked(
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(rows) { row in
                                rowView(row, seen: seen, picker: pickerRow)
                            }
                            if showsTyping {
                                ElioTypingBubble()
                                    .transition(.opacity)
                            }
                            Color.clear
                                .frame(height: 1)
                                .id(bottomID)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(key: ElioWidthKey.self,
                                                       value: proxy.size.width)
                            }
                        )
                        .animation(.easeOut(duration: 0.2), value: showsTyping)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .defaultScrollAnchor(.bottom)
                    .contentMargins(.bottom, 96, for: .scrollContent)
                    .onPreferenceChange(ElioWidthKey.self) { threadWidth = $0 }
                )
                .overlay(alignment: .bottom) { composerBar }
                .overlay(alignment: .top) { topFade }
                .onAppear { scrollToBottom(proxy, animated: false) }
                .onChange(of: rows.last?.id) { _, _ in scrollToBottom(proxy, animated: true) }
                .onChange(of: appState.streamingText) { _, _ in scrollToBottom(proxy, animated: false) }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button {
                        showsChats = true
                    } label: {
                        ElioAvatar(asset: avatarAsset, state: agentState)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: "Elio"))
                    .accessibilityValue(Text(verbatim: agentStateWords))
                    .accessibilityHint(Text(verbatim: "Opens your chats and settings"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.startNewChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                    }
                    .disabled(previewRows == nil && !appState.canTapNewChat)
                    .accessibilityLabel(Text(verbatim: "New chat"))
                }
            }
            .sheet(isPresented: $showsChats) {
                ElioChatsSheet(onOpenSettings: onOpenSettings)
                    .environmentObject(appState)
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: ElioRow, seen: String?, picker: String?) -> some View {
        Group {
            switch row.kind {
            case .user, .agent:
                ElioBubble(row: row,
                           canReact: { canReactNow(row) },
                           startsWithPicker: row.id == picker) { emoji in
                    Task { await appState.react(to: row.id, with: emoji) }
                }
                if row.id == seen {
                    Text(verbatim: "Seen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 2)
                        .padding(.trailing, 4)
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

    /// The field floats: no bar behind it, just the page colour fading up so
    /// the thread slides away under the glass.
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
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    /// Asked when a finger lands on a bubble, so drawing never scans the
    /// transcript for what can be reacted to.
    private func canReactNow(_ row: ElioRow) -> Bool {
        guard previewRows == nil,
              let message = appState.messages.first(where: { $0.id == row.id })
        else { return false }
        return appState.canReact(to: message)
    }

    private var avatarAsset: String {
        colorScheme == .dark ? AppIconChoice.dark.previewAssetName
            : AppIconChoice.light.previewAssetName
    }

    /// What the persona is saying at a glance: something is waiting on him,
    /// this chat is working, a chat finished while he was here, or nothing.
    private var agentState: ElioAvatar.State {
        if let previewState { return previewState }
        if currentNeedsYou || otherNeedsYou { return .needsYou }
        if appState.turnState.isRunning { return .working }
        if otherFinished { return .finished }
        return .idle
    }

    private var agentStateWords: String {
        switch agentState {
        case .needsYou: return "Needs you"
        case .working: return "Working"
        case .finished: return "A chat finished"
        case .idle: return "Idle"
        }
    }

    private var openSessionIDs: Set<String> {
        var ids = Set(appState.liveChatSessionIDs())
        if let active = appState.activeSessionId { ids.insert(active) }
        return ids
    }

    private var currentNeedsYou: Bool {
        appState.pendingClarifyMessageID != nil
    }

    /// A wait in a chat that isn't the one on screen.
    private var otherNeedsYou: Bool {
        let open = openSessionIDs
        return appState.needsYou.items.contains { item in
            item.sessionIDs.contains { !open.contains($0) }
        }
    }

    /// Something landed unread somewhere else, so the dot is not for this chat.
    private var otherFinished: Bool {
        let open = openSessionIDs
        return appState.sessions.contains { $0.isUnread == true && !open.contains($0.id) }
    }

    /// Messages slide up into a blur and a darkening gradient instead of
    /// stopping at a hard bar. Soft at its lower edge, so nothing has a seam.
    private var topFade: some View {
        let page = Color(uiColor: .systemBackground)
        return ZStack {
            Rectangle().fill(.ultraThinMaterial)
            LinearGradient(colors: [page.opacity(0.92), page.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
        }
        .frame(height: 150)
        .mask(
            LinearGradient(stops: [.init(color: .black, location: 0.5),
                                   .init(color: .clear, location: 1)],
                           startPoint: .top, endPoint: .bottom)
        )
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
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
        let originalDraft = draft
        let text = originalDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let pending = pendingFreeTextQuestion() {
            draft = ""
            Task {
                let accepted = await appState.respondToClarify(requestId: pending.requestId,
                                               questionId: pending.questionId,
                                               answer: text)
                if !accepted { restoreDraft(originalDraft) }
            }
            return
        }
        draft = ""
        following = true
        Task {
            let sent = await appState.sendMessage(text)
            if !sent { restoreDraft(originalDraft) }
        }
    }

    private func restoreDraft(_ text: String) {
        let parts = [appState.dashboardIDOnScreen?.uuidString ?? "", appState.activeProfile,
                     appState.activeSessionId ?? ""]
        let currentScope = parts.map { "\($0.utf8.count):\($0)" }.joined()
        guard let draftSessionID, appState.elioShowsConfirmedConversation,
              appState.activeSessionId == draftSessionID, currentScope == draftScope,
              draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        draft = text
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
