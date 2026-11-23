# Elio personal fork — PASS2 (uncommitted)

This is a private-purpose fork of Conduit, not an upstream contribution. The
recorded upstream is `git@github.com:kaishi00/hermes-conduit.git`, revision
`47d3f9e22d4245de8aedd78174068b8e5dfe033c` (`upstream/main` at the start of
this work). Conduit is copyright 2026 kaishi00 and distributed under the MIT
license; the original `LICENSE` remains in the repository.

The personal overlay enables `ELIO_PERSONAL` on the app and unit-test targets only.
`MainView.sidebarLayoutContent` selects `ElioConversationShell`: one conversation,
with an Elio header button opening MainView's existing Settings sheet. There are
no tabs, sidebar gestures, bot/group/work lists or session/profile pickers on
normal launch. Cross-chat Needs you banners (which open a chat picker) are
hidden; the pinned chat's own clarification cards remain. RootView's pairing and MainView's shared lifecycle, sheets and
voice handling remain in place. Without the flag the existing upstream shell and
notification behavior remain selected; shared screens have not been deleted.

## Conversation identity and recovery

The first verified live bot roster selects the unique `isDefault` profile, or
the exact `default` profile on older servers without that field. It never picks
by activity or by the workspace's last selected session. A profile-only pin is
saved under a key containing the dashboard UUID and normalized server URL.
Once pinned, roster ordering and a changed default cannot silently select
another bot. A missing/renamed pin, duplicate default, missing capability or
failed roster read produces an explicit unavailable state with Retry. Restore
the original profile on the server or repair/re-pair the connection in Settings;
there is no in-app pin reassignment UI.

On launch and reconnect the shell uses `connectionComesUp`,
`loadChatResumeBotRoster` and `openBotChatOutcome(for:)`. The existing opener
owns authoritative lookup, compression lineage, the single-flight fence and
opening the persistent canonical Bot Chat; only its confirmed-absence path may
create the initial canonical chat. No personal session lookup, most-recent
fallback or unconditional new-session call was added. Existing automatic resume
may still load another chat internally before the canonical open takes ownership;
the shell withholds its transcript and composer. Only a successful canonical
open captures in-memory server/dashboard, workspace-profile, bot-profile and
session-alias evidence to display ChatView. A confirmed chat stays mounted
through same-scope reconnect validation. Authoritative lookup of the same
registry carries its new runtime tip forward before the ordinary opener
changes aliases; a different registry or scope/pin mismatch retires that proof.

The personal gate at `openNotificationTargetOutcome` checks the dashboard,
normalized server scope and existing pinned profile before waiting on connection
or reading the roster. A correctly scoped cold notification can wait for connection,
then use the existing authoritative `findBotChat` / `BotChatResolver` lookup.
Only the selected canonical registry id, its resolved tip, and canonical lookup
rows resolving to that same tip authorize a target. Both runtime and supplied
durable ids must agree with that evidence. The canonical opener runs before
normal routing; the opener's scope/client/epoch and current pin are rechecked.
Different profiles/dashboards, rooms, empty/whitespace ids, missing pins and
conflicting/unproved ids fail before dashboard switching or decision migration.
A matching profile alone never authorizes a session. The notification bridge
is unchanged. Historical compression ids absent from authoritative lookup still
fail closed; no arbitrary alias is inferred from a notification.

If another existing advanced flow opens a different chat, ChatView is withheld
and Retry returns through the canonical opener. Those hidden advanced flows
(including Siri, widgets, bot links, calls, multi-dashboard controls and Settings
pages) have not all been restricted to one thread in this bounded pass. The
normal personal route is the pinned Bot Chat; this is not a general prohibition
on every inherited background operation.

## Development build identity

On a Mac with Xcode and XcodeGen installed, from the repository root generate
with `xcodegen generate --spec personal/project.yml --project-root .`, then
supply your own Apple Developer team as `DEVELOPMENT_TEAM` in Xcode or on the
`xcodebuild` command line. The overlay clears the upstream team default, uses
`com.hamishburke.elio`, product name Elio, and `elio://`. It embeds no
extensions or Watch app and has empty entitlements, so it shares no app group
or keychain entitlement with production. It retains the existing WebRTC package;
no new package is added. `CFBundleName` in the existing Info.plist expands
`PRODUCT_NAME` to Elio (there is no overriding localized display-name key).
`PRODUCT_MODULE_NAME` stays Conduit so existing `@testable import Conduit` tests
can exercise the personal build. This configuration has not been generated or
built; Linux has neither Xcode/XcodeGen nor a Swift toolchain here.

The basic build cannot validate background push. An independent push deployment
requires an Apple App ID and provisioning with push enabled, a matching APNs
topic and credentials, a separately configured relay and compatible notification
service extension/entitlements. The included app configuration otherwise falls
back to the upstream default relay when its relay setting is blank; do not enable
or register push against that relay as a substitute for independent provisioning.
No signing credentials belong in this repository.

## Personal presentation, composer and durable drafts

The native SwiftUI shell uses an opaque adaptive system background, with no
drifting backdrop. Its single header button combines the existing bot avatar
(when identity is confirmed), Elio name and connection state and opens the
existing Settings sheet. Unverified identity uses a native person-circle symbol.
The personal composer uses the existing editor with attachment, dictation and
one trailing action. During dictation and at accessibility text sizes the
editor spans its own row, with controls below and the action at the trailing
edge. AnyLayout preserves the editor instance as the arrangement changes.
Only glyphs are capped; Stop / Cancel / Transcribing / Done inherit the
requested text size and wrap within their fixed-width slot. The mic remains reachable with
typed text, and becomes Cancel transcription while waiting for Hermes. Cancel
uses the existing service cancellation, leaves the draft intact and releases any
saved recording to the existing Retry notice; it never sends. Clips below the
existing recording retention threshold are not guaranteed a retry. Ordinary
single-choice clarify cards retain their controls and the ordinary text composer.
Model/context/agent/call controls, predictive rows, slash/mention suggestions and
advanced send menus are hidden from normal personal texting. Full editor,
attachment/quote chips, state notices, pending sends and retry paths are retained.
Controls have 44-point targets and explicit accessibility names; motion added by
this pass respects Reduce Motion. Dynamic Type and VoiceOver still need device
validation, particularly narrow screens at the largest accessibility sizes.

Reasoning/tool logs are hidden through local value projections of display
preferences, including the live thinking/tool details. No profile setting is
written to Hermes. Long-work status, final messages, attachments and clarify
cards remain. Personal text bubbles use opaque system surfaces and primary text;
Liquid Glass is confined to existing controls and the header. TranscriptScroller,
keyboard handling and native insertion own scroll behavior unchanged. There is
no fabricated Seen/read status or new transport acknowledgement.

`ComposerDraftStore` now has opt-in personal persistence in the AppState-injected
UserDefaults. Tests inject isolated suites; the memory-only initializer remains
available. Records contain dashboard UUID + normalized server URL, profile,
session id, durable owner, text (including editable dictation transcript),
attachments and reply reference. No saved dashboard, durable owner or confirmed
scope means no disk record. The canonical opener captures its authoritative registry id as the draft owner,
even when the ordinary session list hides Bot Chats. Draft keys retain the
workspace profile captured by that open; notification validation separately
uses the pinned bot profile. Ownership requires exact workspace, dashboard
and normalized-server agreement. Existing capacity, alias
migration and owner checks still apply. Records restore into the composer only through its normal load path;
restoration transmits nothing. The last 300 ms of edits may be lost on abrupt
process termination before a coalesced write. Background, disappearance, send and
removal paths flush explicitly. Successful-send removal uses the captured draft
generation, so it cannot remove a newer edit. Signout/clear cancels deferred
writes and old composer generations cannot save themselves back.

## Recovery and validation limits

A conversation verified in this process retains existing offline behavior. Cold
offline launch still withholds saved history and the composer with an explicit
unavailable state. The existing offline cache is keyed by dashboard/profile and
its kept bot copy does not establish the normalized-server-and-pin canonical
proof required by this shell; the runtime identity index is not a persisted
canonical pin proof. PASS2 does not add a new transcript identity registry or
trust a bare saved session pointer. Durable drafts remain on disk even while the
transcript is withheld and return after the same conversation is verified.
Retry force-refreshes the roster. No unsafe cold offline fallback was added.

`RootView.swift`, the canonical opener, pending-send lifecycle and existing
clarification/voice services remain owners of their shared flows. Hidden
advanced entry points are not comprehensively restricted. New personal copy is
verbatim English. No Swift/Xcode/XcodeGen, simulator or device was available on
this Linux host. The PASS2 XCTest additions extend `BotModeTests` and
`ComposerDraftStoreTests` without adding a class and have not been executed.
The personal overlay defines the flag for the unit-test target so these tests
can run against the personal app on a Mac. Static checks cannot prove compilation
or interaction quality. The parent owns the existing personal GitHub workflow;
it was neither changed nor triggered in this pass.

PASS1 comparison commit is `8b907adca30d59944f16758aeae7a858e6801267` and remains
intact. PASS2 is deliberately uncommitted. Commands and actual results are in
`personal/VALIDATION.md`; device procedures and their unrun status remain in
`personal/ACCEPTANCE.md`.
