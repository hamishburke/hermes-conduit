#if ELIO_PERSONAL
import SwiftUI

/// Replaces only MainView's navigation surface; its lifecycle and sheets
/// still own voice, settings, clarifications and connection recovery.
struct ElioConversationShell: View {
    @EnvironmentObject private var appState: AppState
    let onOpenSettings: () -> Void
    @State private var retry = 0
    @State private var opening = false
    @State private var failure: String?

    private struct OpenRequest: Equatable {
        let scope: ElioConversationScope?
        let connected: Bool
        let retry: Int
    }

    private var request: OpenRequest {
        OpenRequest(scope: appState.elioConversationScope, connected: appState.isConnected, retry: retry)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ConduitBackdrop(drifts: true)
                if appState.elioShowsConfirmedConversation {
                    ChatView()
                        .composerLayoutFromWidth()
                        .readableChatColumn()
                } else {
                    unavailable
                }
            }
            .windowSideContent()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onOpenSettings) {
                        Text(verbatim: "Elio").scaledFont(.headline)
                    }
                    .accessibilityLabel(Text(verbatim: "Elio settings"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ConnectionStatusIndicator()
                }
            }
        }
        .task(id: request) { await openConversation() }
        .onAppear { appState.dismissSidebarDrawer() }
    }

    private var unavailable: some View {
        VStack(spacing: 16) {
            if opening { ProgressView() }
            Text(verbatim: opening ? "Opening your conversation…" : "Conversation unavailable")
                .scaledFont(.headline)
            Text(verbatim: failure ?? "Connect to Hermes, then retry your pinned conversation.")
                .scaledFont(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { retry += 1 } label: {
                Text(verbatim: "Retry")
            }
            .buttonStyle(.borderedProminent)
            .disabled(opening)
        }
        .padding(24)
    }

    @MainActor
    private func openConversation() async {
        let expectedScope = appState.elioConversationScope
        opening = true
        failure = nil
        defer { if !Task.isCancelled { opening = false } }
        _ = await appState.connectionComesUp(within: AppState.listOpenConnectionWait)
        guard !Task.isCancelled, let scope = expectedScope,
              scope == appState.elioConversationScope else { return }
        guard appState.isConnected else {
            failure = "Hermes is offline. Your conversation will reopen when it reconnects."
            return
        }
        appState.elioOpenedConversation = nil
        // Join the connection's existing roster flight, or refresh it. A kept
        // list is not authority for choosing the default bot on a new pairing.
        if retry > 0 {
            await appState.refreshBotRoster()
        } else {
            await appState.loadChatResumeBotRoster()
        }
        guard !Task.isCancelled, scope == appState.elioConversationScope else { return }
        guard appState.botRosterVerifiedForCurrentConnection else {
            failure = "Could not verify this server's default bot. Check the connection in Elio settings, then retry."
            return
        }
        let pinned = appState.defaults.string(forKey: scope.pinStorageKey)
        guard let bot = ElioConversationSelection.bot(in: appState.botRoster, pinnedProfile: pinned) else {
            failure = "The pinned default bot is unavailable or ambiguous. Restore that profile on this server, then retry."
            return
        }
        appState.defaults.set(bot.name, forKey: scope.pinStorageKey)
        // While resolving, no previous transcript or draft is exposed. The
        // ordinary opener owns cancellation, lookup, lineage and creation.
        let outcome = await appState.openBotChatOutcome(for: bot)
        guard !Task.isCancelled, scope == appState.elioConversationScope else { return }
        guard outcome == .opened, appState.activeBotChatProfile == bot.name,
              let sessionID = appState.activeSessionId else {
            failure = appState.errorMessage ?? "Could not open your canonical Bot Chat. Retry when Hermes is ready."
            return
        }
        var ids = appState.liveChatSessionIDs()
        ids.insert(sessionID)
        appState.elioOpenedConversation = ElioOpenedConversation(scope: scope, profile: bot.name, sessionIDs: ids)
        appState.dismissSidebarDrawer()
    }
}
#endif
