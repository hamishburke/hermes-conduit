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
        let workspaceProfile: String
        let connected: Bool
        let retry: Int
    }

    private var request: OpenRequest {
        OpenRequest(scope: appState.elioConversationScope, workspaceProfile: appState.activeProfile,
                    connected: appState.isConnected, retry: retry)
    }

    var body: some View {
        conversation
    }

    private var conversation: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            if appState.elioShowsConfirmedConversation || appState.elioShowsCachedConversation {
                ElioChatScreen(onOpenSettings: onOpenSettings,
                               draftSessionID: appState.activeSessionId,
                               draftScope: draftScope)
                    .id(draftScope)
                    .readableChatColumn()
                    .safeAreaInset(edge: .top) {
                        if let failure, !appState.elioShowsConfirmedConversation {
                            HStack {
                                Text(verbatim: failure).font(.caption)
                                Spacer()
                                Button(AppLocalization.string("Retry")) { retry += 1 }
                                    .disabled(opening)
                            }
                            .padding(10)
                            .background(.regularMaterial)
                        }
                    }
            } else {
                unavailable
            }
        }
        .windowSideContent()
        .task(id: request) { await openConversation() }
        .onAppear { appState.dismissSidebarDrawer() }
    }

    private var draftScope: String {
        let parts = [appState.dashboardIDOnScreen?.uuidString ?? "", appState.activeProfile,
                     appState.activeSessionId ?? ""]
        return parts.map { "\($0.utf8.count):\($0)" }.joined()
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
            Button(action: onOpenSettings) {
                Text(verbatim: "Settings")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .frame(minHeight: 44)
        }
        .padding(24)
    }

    @MainActor
    private func openConversation() async {
        // Already showing the live thread (the pinned chat, or the New Chat
        // just made): a reconnect must not drag him out of it. A saved copy
        // does not count: the opener still has to reach the real chat.
        if appState.elioShowsConfirmedConversation { return }
        let expectedScope = appState.elioConversationScope
        let workspaceProfile = appState.activeProfile
        let pinned = expectedScope.flatMap { appState.defaults.string(forKey: $0.pinStorageKey) }
        if appState.elioOpenedConversation?.belongsTo(
            scope: expectedScope, workspaceProfile: workspaceProfile, pinnedProfile: pinned) != true {
            appState.elioOpenedConversation = nil
        }
        opening = true
        failure = nil
        defer { if !Task.isCancelled { opening = false } }
        _ = await appState.connectionComesUp(within: AppState.listOpenConnectionWait)
        guard !Task.isCancelled, let scope = expectedScope,
              scope == appState.elioConversationScope, workspaceProfile == appState.activeProfile else { return }
        guard appState.isConnected else {
            failure = AppLocalization.string("Gateway connection is unavailable.")
            return
        }
        // Join the connection's existing roster flight, or refresh it. A kept
        // list is not authority for choosing the default bot on a new pairing.
        if retry > 0 {
            await appState.refreshBotRoster()
        } else {
            await appState.loadChatResumeBotRoster()
        }
        guard !Task.isCancelled, scope == appState.elioConversationScope,
              workspaceProfile == appState.activeProfile,
              pinned == appState.defaults.string(forKey: scope.pinStorageKey) else { return }
        guard appState.botRosterVerifiedForCurrentConnection else {
            failure = AppLocalization.string("A network problem stopped that. Check your connection and try again.")
            return
        }
        guard let bot = ElioConversationSelection.bot(in: appState.botRoster, pinnedProfile: pinned) else {
            appState.elioOpenedConversation = nil
            failure = AppLocalization.string("Conversations unavailable")
            return
        }
        appState.defaults.set(bot.name, forKey: scope.pinStorageKey)
        // Same-scope confirmed ChatView stays mounted while revalidating.
        // The canonical opener invalidates proof if lookup changes lineage.
        let outcome = await appState.openBotChatOutcome(for: bot)
        guard !Task.isCancelled, scope == appState.elioConversationScope,
              workspaceProfile == appState.activeProfile else { return }
        guard outcome == .opened, appState.activeBotChatProfile == bot.name,
              appState.elioShowsConfirmedConversation else {
            failure = appState.errorMessage ?? AppLocalization.string("A network problem stopped that. Check your connection and try again.")
            return
        }
        appState.dismissSidebarDrawer()
    }
}
#endif
