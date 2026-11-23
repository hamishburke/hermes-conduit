# Elio personal fork — PASS1

This is a private-purpose fork of Conduit, not an upstream contribution. The
recorded upstream is `git@github.com:kaishi00/hermes-conduit.git`, revision
`47d3f9e22d4245de8aedd78174068b8e5dfe033c` (`upstream/main` at the start of
this work). Conduit is copyright 2026 kaishi00 and distributed under the MIT
license; the original `LICENSE` remains in the repository.

The personal overlay now enables `ELIO_PERSONAL` on the app target only.
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
PASS1 has no in-app pin reassignment UI.

On launch and reconnect the shell uses `connectionComesUp`,
`loadChatResumeBotRoster` and `openBotChatOutcome(for:)`. The existing opener
owns authoritative lookup, compression lineage, the single-flight fence and
opening the persistent canonical Bot Chat; only its confirmed-absence path may
create the initial canonical chat. No personal session lookup, most-recent
fallback or unconditional new-session call was added. Existing automatic resume
may still load another chat internally before the canonical open takes ownership;
the shell withholds its transcript and composer. Only a successful canonical
open captures in-memory scope/profile/session-alias evidence to display ChatView.

The small personal-only gate at `openNotificationTargetOutcome` rejects targets
outside that confirmed thread **before** dashboard switching or decision-card
migration. Dashboard UUID, server scope, explicit profile and known session ids
must agree; rooms, malformed/unscoped targets and conflicting durable/runtime ids
fail closed. Notifications and session links received before confirmation, or
with an alias not yet confirmed, are refused with an error rather than queued
for a different history. The pin is never changed by a notification, and the
notification bridge itself is unchanged.

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

## Existing behavior retained and PASS1 limits

`RootView.swift` owns pairing and lifecycle; `AppState+OpenChat.swift` and
`AppState+ChatResume.swift` handle chat opening and restoration, including
notification ownership. `ChatView.swift` uses `TranscriptScroller` and the
existing clarify cards. `ComposerBar.swift`, `ComposerDraftStore.swift` and
`AppState+PendingSend.swift` keep drafts and pending sends scoped to their chat,
profile and dashboard. Ordinary drafts are in memory, not guaranteed across a
process death. Dictation inserts recognized words into the draft; Stop ends
recording and the user sends separately. Hermes transcription can continue after
recording stops and failed clips can be retried. Dictation stops at 15 minutes
without a specific limit notice (see `docs/FEATURE_MAP.md`, Dictation and voice
message length). The composer, transcript, clarify UI, offline queue, scroller
and voice-draft mechanisms are reused unchanged, with no fabricated read/Seen
status. A conversation verified during this process can keep its existing
offline presentation; a cold offline launch deliberately withholds the saved
transcript/composer until canonical identity is verified online. New shell copy
is verbatim English in PASS1; the inherited UI retains its existing localization.
These flows have not been compiled or tested on a simulator/device here.

The connected-feature sibling audit is recorded under "Elio personal one-thread
shell" in `docs/FEATURE_MAP.md`: standard app, Watch, CarPlay, widgets, desktop
and notifier need no change for this app-only build flag. Device validation,
signing, push, voice/draft/offline interaction under reconnection, accessibility
and visual polish remain follow-ups. Seven new XCTest methods extend the existing
`BotModeTests` class with selection, pin scoping, confirmed identity and external
route rejection cases; they require a Mac to execute.

Exact local commands, output and skipped verification are in `personal/VALIDATION.md`.
