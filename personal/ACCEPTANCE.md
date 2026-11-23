# Elio acceptance record

This is a test procedure, not evidence of a device or simulator pass. Record the
commit, device, iOS version and build number for every completed run. Never test
against the installed Conduit bundle or change the live Hermes plugin to make a
personal build pass.

## Current boundary

- Source prepared on Linux, which has neither Xcode nor Swift installed.
- Hamish selected his Mac and Apple Developer team for device signing.
- MacBook was offline when discovered. No personal app has been installed.
- Basic personal overlay has no APNs entitlement or notification extension.
  Lock-screen delivery is BLOCKED pending independent APNs/topic/relay provisioning.
- Automated compiler status is the exact personal-branch workflow result, not the
  upstream app's CI. Static Python tests do not prove Swift compiles.

## Simulator and iPhone checklist

| Scenario | Procedure and acceptance | Simulator | iPhone |
| --- | --- | --- | --- |
| Cold launch | Pair once, exchange a message, terminate and launch twice. Same canonical Elio thread, no picker or duplicate chat. | Not run | Not run |
| Text | Type, edit and send. Single bubble, correct thread, transport-backed status only. Failed submission has retry and keeps words. | Not run | Not run |
| Voice draft | Say: "Tomorrow at nine [pause five seconds], no, make that ten. Remind me to take the blue folder." Stop. Edit ten to eleven. Nothing sends until Send. Repeat with text already in the draft. | Not run | Not run |
| Voice failure | Deny mic permission, then interrupt transcription/network. Existing draft remains; failure is visible; retry/cancel cannot send a message. | Not run | Not run |
| Keyboard | Focus, dismiss, reopen, rotate. Send stays at trailing edge; transcript inset follows keyboard. Dictation stop/transcribing/send states remain reachable. | Not run | Not run |
| Upthread | Scroll well above newest. Receive a multi-part reply while keyboard opens/closes. Older reading position holds; quiet jump-to-latest works. | Not run | Not run |
| Clarify | Trigger a real single-select clarification. Tap one option once, see selected result. Repeat answering through ordinary composer. | Not run | Not run |
| Long work | Send task, lock phone before completion, receive notification and open it to the pinned thread with the final reply. Do not count foreground WebSocket receipt as push. | Blocked: APNs | Blocked: APNs |
| Offline | Type a draft, disable network, attempt send once, reconnect. Draft/queued message survives, no duplicates. Repeat while transcription is finishing. | Not run | Not run |
| Relaunch draft | Enter text and editable transcript, terminate and launch. Correct scoped draft returns; successful send does not return as an unsent draft. | Not run | Not run |
| Scope safety | Notification/deep link for another chat/profile/server must not expose or send the pinned draft into that destination. Confirm pin isn't replaced. | Not run | Not run |
| Dynamic Type | Default through largest accessibility size, light and dark. Header/composer/status/question choices wrap and remain operable. | Not run | Not run |
| VoiceOver | Header names destination, transcript order is sensible, record/stop/transcribe/send have distinct labels, option selection is announced. | Not run | Not run |
| Reduce Motion | Enable before launch and during conversation. No drifting background or forced insert/jump animations; keyboard remains native. | Not run | Not run |

## Recording a feel check

On a booted simulator, start with:

```sh
xcrun simctl io booted recordVideo --codec=h264 personal-feel-check.mp4
```

Exercise launch, draft, incoming reply while upthread, jump to latest, dictation
and clarification. End recording with Ctrl-C. Simulator microphone input may not
represent iPhone audio, so do the paused/self-corrected note on the phone too.
Use iOS Screen Recording for that phone run. Redact pairing tokens and private
history before sharing recordings. No recording has been produced yet.
