import Foundation

/// Personal-build policy only. The pin stores a profile, never a session
/// pointer: every launch/reconnect still asks the canonical Bot Chat opener.
struct ElioConversationScope: Codable, Hashable {
    let dashboardID: UUID
    let server: String

    init?(dashboardID: UUID?, server: String?) {
        guard let dashboardID, let server,
              let normalized = try? ConnectionURLPolicy.normalizedBaseURL(server) else { return nil }
        self.dashboardID = dashboardID
        self.server = normalized
    }

    var pinStorageKey: String {
        // Encoding the pair avoids delimiter collisions and scopes a replaced
        // server separately even if its saved-dashboard UUID is retained.
        let pair = [dashboardID.uuidString, server]
        let encoded = (try? JSONEncoder().encode(pair))?.base64EncodedString() ?? ""
        return "elio.personal.profile.v1.\(encoded)"
    }
}

enum ElioConversationSelection {
    // Personal shell copy is deliberately verbatim English in PASS1.
    static let externalOpenUnavailable = "Elio only opens its pinned conversation. Open Elio and retry that conversation."

    /// The target names our pinned scope, even when its identity is not proven
    /// yet: same dashboard, same pinned profile, no room.
    static func matchesPinnedScope(_ target: ConduitNotificationTarget,
                                   scope: ElioConversationScope?, pinnedProfile: String?) -> Bool {
        guard let scope, let pinnedProfile, !pinnedProfile.isEmpty,
              target.dashboardID == scope.dashboardID, !target.hasMalformedDashboardID,
              target.profile == pinnedProfile, target.roomID == nil else { return false }
        return true
    }

    /// Ids a canonical lookup can still prove. An empty or malformed id is
    /// "unproven", never proof of a different thread, so the caller answers it
    /// with a retryable outcome rather than a terminal failure.
    static func hasUsableTargetIDs(_ target: ConduitNotificationTarget) -> Bool {
        let ids = [target.sessionId] + [target.durableSessionID].compactMap { $0 }
        return ids.allSatisfy { !$0.isEmpty && $0 == $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// Preflight before waiting on a connection or touching navigation. A
    /// notification cannot choose the initial pin or another dashboard.
    static func canResolveExternalOpen(_ target: ConduitNotificationTarget,
                                       scope: ElioConversationScope?, pinnedProfile: String?) -> Bool {
        matchesPinnedScope(target, scope: scope, pinnedProfile: pinnedProfile)
            && hasUsableTargetIDs(target)
    }

    /// Only the authoritative canonical resolver's selected lineage is proof.
    /// A matching profile alone never authorizes an arbitrary session id.
    static func resolvedExternalConversation(_ target: ConduitNotificationTarget,
                                             scope: ElioConversationScope, pinnedProfile: String,
                                             workspaceProfile: String,
                                             rows: [BotChatLookupRow], rosterCanonicalID: String?) -> ElioOpenedConversation? {
        guard canResolveExternalOpen(target, scope: scope, pinnedProfile: pinnedProfile),
              case .success(.openExisting(let registry, let resume)) = BotChatResolver.resolve(
                rows: rows, rosterCanonicalID: rosterCanonicalID) else { return nil }
        var ids: Set<String> = [registry, resume]
        for row in rows where row.isCanonicalTitle() && row.resumeTargetID == resume {
            ids.insert(row.id)
        }
        let opened = ElioOpenedConversation(scope: scope, profile: pinnedProfile, workspaceProfile: workspaceProfile, sessionIDs: ids,
                                             durableSessionID: registry)
        return opened.permitsExternalOpen(target, scope: scope) ? opened : nil
    }

    static func bot(in roster: [BotProfile], pinnedProfile: String?) -> BotProfile? {
        if let pinnedProfile {
            // A removed/renamed pin must be repaired explicitly, never
            // substituted with a different bot or its most recent session.
            let matches = roster.filter { $0.name == pinnedProfile && !$0.isKeptCopy }
            return matches.count == 1 ? matches[0] : nil
        }
        let live = roster.filter { !$0.isKeptCopy }
        let defaults = live.filter(\.isDefault)
        if !defaults.isEmpty { return defaults.count == 1 ? defaults[0] : nil }
        let legacyDefault = live.filter { $0.name == "default" }
        return legacyDefault.count == 1 ? legacyDefault[0] : nil
    }
}

/// A chat he walked into himself, from the chats sheet. The bot proof names
/// the pinned conversation and cannot vouch for another one, so this is
/// accepted on its own while one of its ids is the session on screen.
struct ElioEnteredChat: Equatable {
    var sessionIDs: Set<String>
    let dashboardID: UUID
    let profile: String
}

/// Evidence captured only after openBotChatOutcome reports .opened.
/// Kept in memory so an unverified cold-launch saved copy is never sendable.
struct ElioOpenedConversation: Equatable {
    let scope: ElioConversationScope
    let profile: String
    /// The workspace that owns composer keys; independent of the bot profile
    /// used to validate notifications and resume the conversation.
    let workspaceProfile: String
    var sessionIDs: Set<String>
    /// The canonical resolver's registry id; never inferred from a push or
    /// the ordinary session list (which deliberately hides Bot Chats).
    var durableSessionID: String? = nil

    func draftOwner(for key: ComposerDraftKey, scope: ElioConversationScope?) -> String? {
        guard key.dashboard == self.scope.dashboardID,
              self.scope == scope, key.profile == workspaceProfile,
              sessionIDs.contains(key.sessionID),
              let durableSessionID, !durableSessionID.isEmpty else { return nil }
        return durableSessionID
    }

    func belongsTo(scope: ElioConversationScope?, workspaceProfile: String, pinnedProfile: String?) -> Bool {
        self.scope == scope && self.workspaceProfile == workspaceProfile && profile == pinnedProfile
    }

    /// Called only with ids from the authoritative canonical resolver. Carry
    /// a newly resolved tip before the ordinary opener changes activeSessionId,
    /// keeping the mounted editor and its same-chat handoff through reconnect.
    func retainingForCanonicalOpen(scope: ElioConversationScope?, workspaceProfile: String,
                                  profile: String, registryID: String, resumeID: String) -> Self? {
        guard belongsTo(scope: scope, workspaceProfile: workspaceProfile, pinnedProfile: profile),
              durableSessionID == registryID else { return nil }
        var copy = self
        copy.sessionIDs.formUnion([registryID, resumeID])
        return copy
    }

    func matches(scope: ElioConversationScope?, profile: String?, sessionID: String?) -> Bool {
        guard self.scope == scope, self.profile == profile, let sessionID,
              !sessionID.isEmpty else { return false }
        return sessionIDs.contains(sessionID)
    }

    func permitsExternalOpen(_ target: ConduitNotificationTarget, scope: ElioConversationScope?) -> Bool {
        guard scope == self.scope, target.dashboardID == self.scope.dashboardID,
              !target.hasMalformedDashboardID, target.roomID == nil,
              target.profile == profile else { return false }
        // If a durable id is supplied it must agree too. Conflicting ids
        // cannot smuggle another history into the selected thread.
        if let durable = target.durableSessionID, !sessionIDs.contains(durable) { return false }
        return sessionIDs.contains(target.sessionId)
    }
}

#if ELIO_PERSONAL
extension ProfileDisplayPreferences {
    /// A value projection only; never written to the profile or Hermes.
    var elioPresentation: Self {
        var copy = self
        copy.showReasoning = false
        copy.thinkingOnRequest = false
        copy.showToolProgress = false
        return copy
    }
}

extension AppState {
    func elioCanonicalDraftOwner(for key: ComposerDraftKey) -> String? {
        guard let opened = elioOpenedConversation,
              opened.belongsTo(scope: elioConversationScope, workspaceProfile: activeProfile,
                               pinnedProfile: defaults.string(forKey: opened.scope.pinStorageKey)) else { return nil }
        return opened.draftOwner(for: key, scope: elioConversationScope)
    }

    /// A cold tap may resolve the pinned chat, but never opens the target
    /// first to discover what it is. No decision migration occurs here.
    func elioPrepareExternalOpen(_ target: ConduitNotificationTarget) async -> Bool {
        guard let scope = elioConversationScope,
              let pin = defaults.string(forKey: scope.pinStorageKey),
              ElioConversationSelection.canResolveExternalOpen(target, scope: scope, pinnedProfile: pin) else { return false }
        let workspaceProfile = activeProfile
        _ = await connectionComesUp(within: Self.listOpenConnectionWait)
        guard !Task.isCancelled, elioConversationScope == scope, activeProfile == workspaceProfile,
              isConnected, let client else { return false }
        let epoch = botRosterEpoch
        await loadChatResumeBotRoster()
        guard !Task.isCancelled, botOpenFenceIsCurrent(epoch: epoch, client: client),
              elioConversationScope == scope, activeProfile == workspaceProfile, botRosterVerifiedForCurrentConnection,
              defaults.string(forKey: scope.pinStorageKey) == pin,
              let bot = ElioConversationSelection.bot(in: botRoster, pinnedProfile: pin) else { return false }
        do {
            let rows: [BotChatLookupRow]
            if let lookup = chatResumeLifecycleOperations.findBotChat {
                rows = try await lookup(client, bot.name)
            } else {
                rows = try await client.findBotChatSession(profile: bot.name)
            }
            guard !Task.isCancelled, botOpenFenceIsCurrent(epoch: epoch, client: client),
                  elioConversationScope == scope, activeProfile == workspaceProfile,
                  let proof = ElioConversationSelection.resolvedExternalConversation(
                    target, scope: scope, pinnedProfile: pin, workspaceProfile: workspaceProfile,
                    rows: rows, rosterCanonicalID: bot.canonicalSessionID) else { return false }
            guard await openBotChatOutcome(for: bot) == .opened,
                  !Task.isCancelled, botOpenFenceIsCurrent(epoch: epoch, client: client),
                  elioConversationScope == scope, activeProfile == workspaceProfile, activeBotChatProfile == pin,
                  defaults.string(forKey: scope.pinStorageKey) == pin,
                  elioOpenedConversation?.durableSessionID == proof.durableSessionID,
                  !proof.sessionIDs.isDisjoint(with: liveChatSessionIDs()) else { return false }
            elioOpenedConversation = ElioOpenedConversation(scope: scope, profile: pin,
                                                           workspaceProfile: workspaceProfile,
                                                           sessionIDs: proof.sessionIDs.union(elioOpenedConversation?.sessionIDs ?? []).union(liveChatSessionIDs()),
                                                           durableSessionID: elioOpenedConversation?.durableSessionID)
            return elioShowsConfirmedConversation
        } catch { return false }
    }

    var elioConversationScope: ElioConversationScope? {
        ElioConversationScope(dashboardID: dashboardIDOnScreen, server: connection?.baseUrl)
    }

    var elioShowsConfirmedConversation: Bool {
        // The chat the New Chat button just made is the pinned bot's own
        // thread; the opener's proof still names the session it replaced.
        if let created = shownChat.newChatOpenedSessionID, activeSessionId == created,
           farChat == nil, activeRoomSurface == nil, !showsPendingNewChat,
           elioConversationScope != nil {
            return true
        }
        // A chat he opened from the sheet is his to see, whatever the pinned
        // bot proof says about it.
        if let entered = elioEnteredChat, let scope = elioConversationScope,
           entered.dashboardID == scope.dashboardID, entered.profile == activeProfile,
           let sessionID = activeSessionId, entered.sessionIDs.contains(sessionID),
           farChat == nil, activeRoomSurface == nil, !showsPendingNewChat {
            return true
        }
        guard let opened = elioOpenedConversation, farChat == nil,
              activeRoomSurface == nil, !showsPendingNewChat,
              savedCopyScrollSessionKey == nil else { return false }
        guard opened.belongsTo(scope: elioConversationScope, workspaceProfile: activeProfile,
                               pinnedProfile: defaults.string(forKey: opened.scope.pinStorageKey)) else { return false }
        return opened.matches(scope: elioConversationScope,
                              profile: activeBotChatProfile, sessionID: activeSessionId)
    }

    /// The saved copy of this scope's conversation, shown while the live one
    /// is still being reached: the thread is on screen from the first frame
    /// instead of a loading state.
    var elioShowsCachedConversation: Bool {
        guard farChat == nil, activeRoomSurface == nil, !showsPendingNewChat,
              let presented = offlineChatPresentation,
              dashboardIDOnScreen != nil else { return false }
        return presented.dashboardID == dashboardIDOnScreen
            && presented.profile == activeProfile
            && !presented.displayedMessages.isEmpty
    }
}
#endif
