import XCTest
@testable import Conduit

extension BotModeTests {
    func testElioColdNotificationRequiresPinnedScopeBeforeCanonicalLookup() throws {
        let scope = try XCTUnwrap(ElioConversationScope(dashboardID: UUID(), server: "https://home.example"))
        func target(profile: String? = "default", dashboard: UUID? = nil,
                    session: String = "root", malformed: Bool = false, room: String? = nil) -> ConduitNotificationTarget {
            ConduitNotificationTarget(profile: profile, sessionId: session, dashboardID: dashboard ?? scope.dashboardID,
                                      hasMalformedDashboardID: malformed, type: "response.ready", roomID: room)
        }
        XCTAssertTrue(ElioConversationSelection.canResolveExternalOpen(target(), scope: scope, pinnedProfile: "default"))
        XCTAssertFalse(ElioConversationSelection.canResolveExternalOpen(target(), scope: scope, pinnedProfile: nil))
        XCTAssertFalse(ElioConversationSelection.canResolveExternalOpen(target(), scope: nil, pinnedProfile: "default"))
        for invalid in [target(profile: "other"), target(profile: nil), target(dashboard: UUID()),
                        target(session: ""), target(session: " root "), target(malformed: true), target(room: "room")] {
            XCTAssertFalse(ElioConversationSelection.canResolveExternalOpen(invalid, scope: scope, pinnedProfile: "default"))
        }
    }

    func testElioColdNotificationUsesCanonicalResolverAndCompressionLineageRatherThanProfileAlone() throws {
        let scope = try XCTUnwrap(ElioConversationScope(dashboardID: UUID(), server: "https://home.example"))
        let rows = [BotChatLookupRow(id: "root", resolvedID: "compressed", title: BotMode.canonicalChatTitle),
                    BotChatLookupRow(id: "old-tip", resolvedID: "compressed", rootTitle: BotMode.canonicalChatTitle),
                    BotChatLookupRow(id: "other-root", resolvedID: "other", title: BotMode.canonicalChatTitle),
                    BotChatLookupRow(id: "ordinary", title: "Other chat")]
        func resolve(_ id: String, durable: String? = "root", lookup: [BotChatLookupRow]? = nil) -> ElioOpenedConversation? {
            let target = ConduitNotificationTarget(profile: "default", sessionId: id, durableSessionID: durable,
                                                   dashboardID: scope.dashboardID, type: "response.ready")
            return ElioConversationSelection.resolvedExternalConversation(target, scope: scope, pinnedProfile: "default",
                                                                          workspaceProfile: "work", rows: lookup ?? rows, rosterCanonicalID: "root")
        }
        XCTAssertNotNil(resolve("root"))
        XCTAssertEqual(resolve("root")?.workspaceProfile, "work")
        XCTAssertEqual(resolve("root")?.draftOwner(for: ComposerDraftKey(
            dashboard: scope.dashboardID, profile: "work", sessionID: "compressed"), scope: scope), "root")
        XCTAssertNil(resolve("root")?.draftOwner(for: ComposerDraftKey(
            dashboard: scope.dashboardID, profile: "default", sessionID: "compressed"), scope: scope))
        XCTAssertNotNil(resolve("compressed"))
        XCTAssertNotNil(resolve("old-tip"))
        XCTAssertNil(resolve("ordinary"))
        XCTAssertNil(resolve("other-root"))
        XCTAssertNil(resolve("compressed", durable: "ordinary"))
        XCTAssertNil(resolve("root", lookup: []), "Unconfirmed absence cannot authorize a notification")
        XCTAssertNil(resolve("root", lookup: [BotChatLookupRow(id: "ordinary", title: "Other chat")]))
    }

    #if ELIO_PERSONAL
    func testElioWorkspaceDraftPersistsAcrossCanonicalAliasRevalidationWithoutCatalogRows() async throws {
        let dashboard = UUID()
        let connection = HermesConnection(baseUrl: "https://home.example", ticket: "test")
        let scope = try XCTUnwrap(ElioConversationScope(dashboardID: dashboard, server: connection.baseUrl))
        let bot = try elioBot("personal", isDefault: true)
        var tip = "runtime-1"
        var registry = "root"
        var revalidating: AppState?
        let operations = ChatResumeLifecycleOperations(
            openSessionWithProfile: { _, id, _, profile in
                XCTAssertEqual(profile, bot.name)
                if let state = revalidating {
                    if registry == "root" {
                        // The ordinary opener has already changed activeSessionId.
                        XCTAssertEqual(state.activeSessionId, tip)
                        XCTAssertTrue(state.elioShowsConfirmedConversation)
                        let old = ComposerDraftKey(dashboard: dashboard, profile: "work", sessionID: "runtime-1")
                        XCTAssertTrue(state.composerDraftKeysAreSameChat(old, state.composerDraftKeyOnScreen))
                    } else {
                        XCTAssertNil(state.elioOpenedConversation, "A different authoritative registry retires the old proof")
                        XCTAssertFalse(state.elioShowsConfirmedConversation)
                    }
                }
                return SessionResumeResult(sessionId: id, storedSessionId: registry, messages: [],
                    snapshot: SessionRuntimeSnapshot(object: ["running": .bool(false)]))
            },
            refreshContext: { _, _ in },
            botRoster: { _ in BotRosterSnapshot(bots: [bot], supportsBotProtocol: true) },
            findBotChat: { _, profile in
                XCTAssertEqual(profile, bot.name)
                return [BotChatLookupRow(id: registry, resolvedID: tip, title: BotMode.canonicalChatTitle)]
            }
        )
        func prepare(_ state: AppState) {
            state.savedDashboardRegistry.activeDashboardID = dashboard
            state.activeProfile = "work"
            state.connection = connection
            state.client = HermesClient(connection: connection, profile: "work")
            state.defaults.set(bot.name, forKey: scope.pinStorageKey)
        }
        let first = makeBotHarness(sessionCatalogLoader: { _ in [] }, lifecycleOperations: operations).appState
        prepare(first)
        await first.refreshBotRoster()
        let opened = await first.openBotChatOutcome(for: bot)
        XCTAssertEqual(opened, .opened)
        XCTAssertEqual(first.activeProfile, "work", "Bot opens preserve the workspace")
        XCTAssertTrue(first.sessions.isEmpty, "The ordinary catalog need not list a Bot Chat")
        let key = first.composerDraftKeyOnScreen
        XCTAssertEqual(key.profile, "work")
        XCTAssertEqual(first.composerDraftOwner(for: key), "root")
        let draft = ComposerDraft(text: "Typed words\nEdited dictation, ready for explicit send.", attachments: [])
        first.composerDraftStore.usePersonalScope(scope)
        first.composerDraftStore.save(draft, for: key, owner: first.composerDraftOwner(for: key))
        first.composerDraftStore.flushPersistence()

        tip = "runtime-2"
        revalidating = first
        first.isConnected = false
        XCTAssertTrue(first.elioShowsConfirmedConversation, "Transport loss keeps the confirmed editor mounted")
        first.isConnected = true
        let revalidated = await first.openBotChatOutcome(for: bot)
        XCTAssertEqual(revalidated, .opened)
        XCTAssertEqual(first.composerDraftOwner(for: key), "root", "Old authoritative aliases stay in the same lineage")
        revalidating = nil

        let second = makeBotHarness(sessionCatalogLoader: { _ in [] }, reusing: first.defaults,
                                    lifecycleOperations: operations).appState
        prepare(second)
        await second.refreshBotRoster()
        let reopened = await second.openBotChatOutcome(for: bot)
        XCTAssertEqual(reopened, .opened)
        let newKey = second.composerDraftKeyOnScreen
        XCTAssertEqual(newKey.sessionID, tip)
        XCTAssertTrue(second.sessions.isEmpty)
        second.composerDraftStore.usePersonalScope(scope)
        XCTAssertEqual(second.composerDraftStore.draft(for: key), draft)
        XCTAssertEqual(second.composerDraftStore.owner(of: key), second.composerDraftOwner(for: newKey),
                       "The persisted owner recovers a stranded runtime draft after relaunch")
        second.composerDraftStore.migrateDraft(from: key, to: newKey)
        XCTAssertEqual(second.composerDraftStore.draft(for: newKey), draft)
        XCTAssertEqual(second.composerDraftOwner(for: newKey), "root")

        XCTAssertNil(second.composerDraftOwner(for: ComposerDraftKey(dashboard: UUID(), profile: "work", sessionID: tip)))
        for profile in ["personal", "other"] {
            XCTAssertNil(second.composerDraftOwner(for: ComposerDraftKey(dashboard: dashboard, profile: profile, sessionID: tip)))
        }
        second.activeProfile = "other"
        XCTAssertNil(second.composerDraftOwner(for: newKey))
        XCTAssertFalse(second.elioShowsConfirmedConversation)
        second.activeProfile = "work"
        second.defaults.set("other-bot", forKey: scope.pinStorageKey)
        XCTAssertNil(second.composerDraftOwner(for: newKey))
        XCTAssertFalse(second.elioShowsConfirmedConversation)
        second.defaults.set(bot.name, forKey: scope.pinStorageKey)
        second.connection = HermesConnection(baseUrl: "https://other.example", ticket: "test")
        XCTAssertNil(second.composerDraftOwner(for: newKey))
        XCTAssertFalse(second.elioShowsConfirmedConversation)
        second.connection = connection

        registry = "different-root"
        tip = "different-runtime"
        revalidating = second
        let replaced = await second.openBotChatOutcome(for: bot)
        XCTAssertEqual(replaced, .opened)
        XCTAssertNil(second.composerDraftOwner(for: newKey))
        XCTAssertEqual(second.composerDraftOwner(for: second.composerDraftKeyOnScreen), registry)
        revalidating = nil
    }

    func testElioCanonicalDraftOwnerRequiresScopeProfileAndKnownSession() throws {
        // The pure evidence helper is also used by AppState's owner API.
        let scope = try XCTUnwrap(ElioConversationScope(dashboardID: UUID(), server: "https://home.example"))
        let key = ComposerDraftKey(dashboard: scope.dashboardID, profile: "work", sessionID: "runtime")
        let opened = ElioOpenedConversation(scope: scope, profile: "personal", workspaceProfile: "work", sessionIDs: ["root", "runtime"], durableSessionID: "root")
        XCTAssertEqual(opened.draftOwner(for: key, scope: scope), "root")
        XCTAssertNil(opened.draftOwner(for: key, scope: nil))
        XCTAssertNil(opened.draftOwner(for: ComposerDraftKey(dashboard: UUID(), profile: key.profile, sessionID: key.sessionID), scope: scope))
        XCTAssertNil(opened.draftOwner(for: ComposerDraftKey(dashboard: key.dashboard, profile: "other", sessionID: key.sessionID), scope: scope))
        XCTAssertNil(opened.draftOwner(for: ComposerDraftKey(dashboard: key.dashboard, profile: key.profile, sessionID: "unrelated"), scope: scope))
        let otherServer = try XCTUnwrap(ElioConversationScope(dashboardID: scope.dashboardID, server: "https://other.example"))
        XCTAssertNil(opened.draftOwner(for: key, scope: otherServer))
        let carried = try XCTUnwrap(opened.retainingForCanonicalOpen(
            scope: scope, workspaceProfile: "work", profile: "personal", registryID: "root", resumeID: "new-tip"))
        XCTAssertTrue(carried.sessionIDs.isSuperset(of: ["runtime", "new-tip"]))
        XCTAssertNil(opened.retainingForCanonicalOpen(
            scope: scope, workspaceProfile: "other", profile: "personal", registryID: "root", resumeID: "new-tip"))
        XCTAssertNil(opened.retainingForCanonicalOpen(
            scope: scope, workspaceProfile: "work", profile: "other", registryID: "root", resumeID: "new-tip"))
        XCTAssertNil(opened.retainingForCanonicalOpen(
            scope: otherServer, workspaceProfile: "work", profile: "personal", registryID: "root", resumeID: "new-tip"))
        XCTAssertNil(opened.retainingForCanonicalOpen(
            scope: scope, workspaceProfile: "work", profile: "personal", registryID: "different", resumeID: "new-tip"))
    }

    func testElioDisplayProjectionDoesNotChangeProfilePreferences() {
        let original = ProfileDisplayPreferences()
        let personal = original.elioPresentation
        XCTAssertTrue(original.showReasoning)
        XCTAssertTrue(original.showToolProgress)
        XCTAssertFalse(personal.showReasoning)
        XCTAssertFalse(personal.showToolProgress)
        XCTAssertFalse(personal.thinkingOnRequest)
        XCTAssertEqual(original.showReviews, personal.showReviews)
    }
    #endif

    private func elioBot(_ name: String, isDefault: Bool = false, kept: Bool = false) throws -> BotProfile {
        let payload: AnyCodable = .object(["profiles": .array([
            .object(["name": .string(name), "is_default": .bool(isDefault)])
        ])])
        var bot = try XCTUnwrap(BotRosterDecoder.decode(payload)?.bots.first)
        bot.isKeptCopy = kept
        return bot
    }

    func testElioSelectsServerDefaultRatherThanRosterOrderOrActiveBot() throws {
        let other = try elioBot("busy-agent")
        let primary = try elioBot("personal", isDefault: true)
        XCTAssertEqual(ElioConversationSelection.bot(in: [other, primary], pinnedProfile: nil)?.name, "personal")
        XCTAssertEqual(ElioConversationSelection.bot(in: [primary, other], pinnedProfile: nil)?.name, "personal")
    }

    func testElioLegacyDefaultRequiresAnExactDefaultProfile() throws {
        let ordinary = try elioBot("busy-agent")
        XCTAssertNil(ElioConversationSelection.bot(in: [ordinary], pinnedProfile: nil))
        let primary = try elioBot("default")
        XCTAssertEqual(ElioConversationSelection.bot(in: [ordinary, primary], pinnedProfile: nil)?.name, "default")
    }

    func testElioPinSurvivesDefaultChangeAndNeverSubstitutesMissingOrRenamedBot() throws {
        let pinned = try elioBot("personal")
        let newDefault = try elioBot("replacement", isDefault: true)
        XCTAssertEqual(ElioConversationSelection.bot(in: [newDefault, pinned], pinnedProfile: "personal")?.name, "personal")
        XCTAssertNil(ElioConversationSelection.bot(in: [newDefault], pinnedProfile: "personal"))
        var renamed = try elioBot("new-name", isDefault: true)
        renamed.previousNames = ["personal"]
        XCTAssertNil(ElioConversationSelection.bot(in: [renamed], pinnedProfile: "personal"))
    }

    func testElioRejectsAmbiguousDefaultsDuplicatePinsAndKeptRoster() throws {
        let first = try elioBot("first", isDefault: true)
        let second = try elioBot("second", isDefault: true)
        XCTAssertNil(ElioConversationSelection.bot(in: [first, second], pinnedProfile: nil))
        XCTAssertNil(ElioConversationSelection.bot(in: [first, first], pinnedProfile: "first"))
        let kept = try elioBot("default", kept: true)
        XCTAssertNil(ElioConversationSelection.bot(in: [kept], pinnedProfile: nil))
        XCTAssertNil(ElioConversationSelection.bot(in: [kept], pinnedProfile: "default"))
    }

    func testElioPinIsScopedByBothDashboardAndServer() throws {
        let dashboard = UUID()
        let scope = try XCTUnwrap(ElioConversationScope(dashboardID: dashboard, server: " https://home.example/ "))
        let same = try XCTUnwrap(ElioConversationScope(dashboardID: dashboard, server: "https://home.example"))
        let otherServer = try XCTUnwrap(ElioConversationScope(dashboardID: dashboard, server: "https://other.example"))
        let otherDashboard = try XCTUnwrap(ElioConversationScope(dashboardID: UUID(), server: scope.server))
        XCTAssertEqual(scope.pinStorageKey, same.pinStorageKey)
        XCTAssertNotEqual(scope.pinStorageKey, otherServer.pinStorageKey)
        XCTAssertNotEqual(scope.pinStorageKey, otherDashboard.pinStorageKey)
        XCTAssertNil(ElioConversationScope(dashboardID: nil, server: scope.server))
        XCTAssertNil(ElioConversationScope(dashboardID: dashboard, server: "https://user:secret@home.example"))
    }

    func testElioConfirmedSelectionRequiresScopeProfileAndSessionTogether() throws {
        let scope = try XCTUnwrap(ElioConversationScope(dashboardID: UUID(), server: "https://home.example"))
        let opened = ElioOpenedConversation(scope: scope, profile: "default", workspaceProfile: "default", sessionIDs: ["stored", "runtime"])
        XCTAssertTrue(opened.matches(scope: scope, profile: "default", sessionID: "runtime"))
        XCTAssertTrue(opened.matches(scope: scope, profile: "default", sessionID: "stored"))
        XCTAssertFalse(opened.matches(scope: nil, profile: "default", sessionID: "runtime"))
        XCTAssertFalse(opened.matches(scope: scope, profile: "other", sessionID: "runtime"))
        XCTAssertFalse(opened.matches(scope: scope, profile: "default", sessionID: "unrelated"))
        XCTAssertFalse(opened.matches(scope: scope, profile: "default", sessionID: nil))
    }

    func testElioExternalOpenRejectsOtherThreadsDashboardsProfilesRoomsAndConflictingIDs() throws {
        let scope = try XCTUnwrap(ElioConversationScope(dashboardID: UUID(), server: "https://home.example"))
        let opened = ElioOpenedConversation(scope: scope, profile: "default", workspaceProfile: "default", sessionIDs: ["stored", "runtime"])
        func target(_ session: String = "runtime", profile: String? = "default", dashboard: UUID? = nil,
                    durable: String? = "stored", room: String? = nil, malformed: Bool = false) -> ConduitNotificationTarget {
            ConduitNotificationTarget(profile: profile, sessionId: session, durableSessionID: durable,
                                      dashboardID: dashboard ?? scope.dashboardID,
                                      hasMalformedDashboardID: malformed, type: "response.ready", roomID: room)
        }
        XCTAssertTrue(opened.permitsExternalOpen(target(), scope: scope))
        XCTAssertFalse(opened.permitsExternalOpen(target("unrelated"), scope: scope))
        XCTAssertFalse(opened.permitsExternalOpen(target(profile: "other"), scope: scope))
        XCTAssertFalse(opened.permitsExternalOpen(target(profile: nil), scope: scope))
        XCTAssertFalse(opened.permitsExternalOpen(target(dashboard: UUID()), scope: scope))
        XCTAssertFalse(opened.permitsExternalOpen(target(durable: "unrelated"), scope: scope))
        XCTAssertFalse(opened.permitsExternalOpen(target(room: "room"), scope: scope))
        XCTAssertFalse(opened.permitsExternalOpen(target(malformed: true), scope: scope))
        XCTAssertFalse(opened.permitsExternalOpen(target(), scope: nil))
        XCTAssertFalse(opened.permitsExternalOpen(
            ConduitNotificationTarget(profile: "default", sessionId: "runtime", type: "response.ready"), scope: scope))
    }
}
