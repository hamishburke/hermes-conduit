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

/// Evidence captured only after openBotChatOutcome reports .opened.
/// Kept in memory so an unverified cold-launch saved copy is never sendable.
struct ElioOpenedConversation: Equatable {
    let scope: ElioConversationScope
    let profile: String
    let sessionIDs: Set<String>

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
extension AppState {
    var elioConversationScope: ElioConversationScope? {
        ElioConversationScope(dashboardID: dashboardIDOnScreen, server: connection?.baseUrl)
    }

    var elioShowsConfirmedConversation: Bool {
        guard let opened = elioOpenedConversation, farChat == nil,
              activeRoomSurface == nil, !showsPendingNewChat,
              savedCopyScrollSessionKey == nil else { return false }
        return opened.matches(scope: elioConversationScope,
                              profile: activeBotChatProfile, sessionID: activeSessionId)
    }
}
#endif
