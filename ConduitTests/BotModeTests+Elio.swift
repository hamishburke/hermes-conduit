import XCTest
@testable import Conduit

extension BotModeTests {
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
        let opened = ElioOpenedConversation(scope: scope, profile: "default", sessionIDs: ["stored", "runtime"])
        XCTAssertTrue(opened.matches(scope: scope, profile: "default", sessionID: "runtime"))
        XCTAssertTrue(opened.matches(scope: scope, profile: "default", sessionID: "stored"))
        XCTAssertFalse(opened.matches(scope: nil, profile: "default", sessionID: "runtime"))
        XCTAssertFalse(opened.matches(scope: scope, profile: "other", sessionID: "runtime"))
        XCTAssertFalse(opened.matches(scope: scope, profile: "default", sessionID: "unrelated"))
        XCTAssertFalse(opened.matches(scope: scope, profile: "default", sessionID: nil))
    }

    func testElioExternalOpenRejectsOtherThreadsDashboardsProfilesRoomsAndConflictingIDs() throws {
        let scope = try XCTUnwrap(ElioConversationScope(dashboardID: UUID(), server: "https://home.example"))
        let opened = ElioOpenedConversation(scope: scope, profile: "default", sessionIDs: ["stored", "runtime"])
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
