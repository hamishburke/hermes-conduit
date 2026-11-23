# Purpose-built thread

The one-thread pass hid Conduit's navigation but still drew Conduit's chat:
`ChatView`, a `UICollectionView` transcript, and the 3,600-line `ComposerBar`.
Hamish's verdict on that build was that it read as a wrapper: the old app with
its bars taken away. This pass replaces the presentation instead of hiding it.
AppState stays the engine (connection, pinning, streaming, sending, clarify and
approval answers); the thread, its bubbles, its composer and its header are new
code in `Conduit/Views/Elio/`.

## What is drawn

The look is taken from the reference thread Hamish sent: system blue outgoing
bubbles, light grey incoming ones, uniform 20-point rounding with no tails and
no avatars, a "Seen" receipt under the last sent message, and choices drawn as
messages rather than as a form.

- `ElioRow` turns `AppState.messages` plus `streamingText` into four row kinds:
  user, agent, clarify, approval. Tool, reasoning, partial-as-working and system
  rows are dropped rather than styled.
- `ElioBubble`: `systemBlue` right for Hamish, `secondarySystemBackground` left
  for Elio, both tapping system type through `MarkdownText`, runs from one
  speaker sitting 3 points closer together.
- `ElioTypingBubble`: three dots while a turn runs with no text yet. Static
  under Reduce Motion.
- `ElioClarifyCard` and `ElioApprovalCard`: the question or command as a grey
  bubble, each choice as its own grey bubble under it, and the outcome in grey
  once settled. A free-text clarify is answered through the composer, whose
  prompt becomes "Answer Elio" while one is pending.
- `ElioComposer`: one growing `TextField` reading "Message Elio", send arrow
  inside the pill so the field never changes width as typing starts.
- `ElioChatScreen`: a `NavigationStack` with an inline "Elio" title and one
  trailing `square.and.pencil` button that calls `AppState.startNewChat()`,
  which starts a fresh session in the same profile. The thread is a
  `ScrollView` + `LazyVStack` on the system background, pinned to the bottom,
  with the composer as a bottom safe-area inset.
- "Seen" is drawn from a real state, not invented: it appears under the last
  message Hamish sent once Elio's reply has begun or a turn is running.

The draft is kept in `@SceneStorage`, so the shell's "your draft is kept"
promise survives the conversation going unavailable.

## What the advisor changed

An advisor pass (`advise.py`, medium thinking, four files attached) asked for a
third less code. Adopted:

- Timestamp parsing and time separators removed. Two `ISO8601DateFormatter`
  parses per row per streaming token was real cost for a divider the screen does
  not need; grouping now uses speaker adjacency only.
- The send arrow moved inside the pill. Outside it, the field shrank 40pt on
  the first keystroke and reflowed the draft.
- `MarkdownText(isStreaming:)` is set on the live row so it uses its streaming
  cache instead of re-parsing the whole string per token.
- Agent bubbles no longer carry a 56pt trailing gap.
- The accessibility label now includes the message text. `.combine` plus a
  fixed label read "You said" and dropped the content.
- `unavailable` gained a Settings button; the shell had removed the only route
  to repairing a pairing while telling the user to check settings.
- Three comments that overclaimed (approval visibility, "the one interactive
  thing", "no Liquid Glass") were corrected.

Declined, with reasons:

- Drop `NavigationStack` and the `.bar` composer for a floating button over a
  gradient. That is custom chrome; the native bar is what Messages does, and the
  brief is native.
- Fold the shell's `openConversation` into AppState. It is the inherited,
  proven pinning and retry path and is not part of presentation.
- Merge the clarify and approval cards into one generic card. They differ in
  payload and answer API; the shared 20 lines are cheaper than the abstraction.

Kept against the advisor's advice: the `-ElioLook` DEBUG build and its
`previewRows` seam. A headless simulator here has no pairing, so this is the
only way to draw, photograph and check the thread without his hands. It is
compiled out of a release build.

## Not proven

Layout and colour on a simulator are evidence; feel is not. Unmeasured: a
200-message transcript, streaming at 30 tokens a second, a clarify arriving
mid-stream, VoiceOver, Dynamic Type at accessibility sizes, iPad, and the real
send path on a paired phone.

## Header, composer, and being there before the connection

- The bar is gone. The thread runs under the status bar and fades into a
  material-plus-gradient mask 150 points tall, so messages slide away instead
  of stopping at a hard edge. The bar itself draws nothing.
- The centre of the bar is the persona's own app-icon artwork in a 30-point
  circle rather than the word "Elio"; tapping it still opens settings. The
  compose button is white with a soft shadow so it reads on both page colours.
- The composer is a floating Liquid Glass field at the bottom over the thread
  (overlay plus a 96-point bottom content margin, not a safe-area bar). The
  microphone sits in the trailing slot exactly where the send arrow appears, so
  the field never has a dead corner: empty shows the mic, typing shows send.
  Dictation goes through the app's own `ComposerDictationService`, writes into
  the draft, and never sends.
- The thread draws the saved copy of the conversation while the live one is
  being reached (`ElioChatScreen.transcript` falls back to
  `offlineChatPresentation.displayedMessages`), and the shell shows that screen
  under `elioShowsCachedConversation`. Hermes' rows replace the saved ones whole
  once the opener lands; the opener still runs, so the saved copy is display
  only and never blocks reaching the real chat.
- New Chat no longer falls through to "Conversation unavailable": the
  confirmation gate accepts the session `startNewChat()` just created, and the
  shell's opener returns early while a live conversation is up, so a reconnect
  cannot drag him back out of a new thread.

Unverified after this pass: dictation on a device (no microphone input here),
the New Chat path and the cached path (both need a paired, signed-in install),
and the floating composer with the keyboard up.

## Walking out of the one thread

- The persona button in the bar opens a sheet of every chat on the gateway,
  with the open one ticked, New Chat, and Settings at the bottom. Settings had
  no visible home before; a hidden tap on the title was the only way in.
- Opening a chat from the sheet extends the shell's proof to that session
  (`elioOpenedConversation.sessionIDs`), so the screen that follows is the
  thread rather than "Conversation unavailable". The same fix pattern as New
  Chat: the proof names the pinned bot's canonical chat, and the gate has to be
  told about the session he actually walked into.
- Rooms Elio created (workstreams, delegate agents, tasks) are not in this
  sheet yet. They are a different object from a session and need their own
  status read; the section is left out rather than faked.

## Updates

- `scripts/elio-release.sh` (fedora) tags `elio-YYYY.MM.DD.N`, pushes the tag
  and publishes it on GitHub with the commits since the last one.
- `scripts/elio-install.sh` (fedora) rsyncs the tree to the Mac, regenerates
  the project, builds for the simulator, and with `--device` builds for the
  phone and installs over the wire. The signed device build still needs the
  one-time GUI Run to register the device; the script says so instead of
  claiming an install it could not make.
- The app reports the newest release in the chats sheet, with its notes and a
  copyable install command. It never claims to have installed anything.

First release: `elio-2026.11.24.1`.
