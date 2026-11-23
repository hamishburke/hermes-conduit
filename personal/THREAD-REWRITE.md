# Purpose-built thread

The one-thread pass hid Conduit's navigation but still drew Conduit's chat:
`ChatView`, a `UICollectionView` transcript, and the 3,600-line `ComposerBar`.
Hamish's verdict on that build was that it read as a wrapper: the old app with
its bars taken away. This pass replaces the presentation instead of hiding it.
AppState stays the engine (connection, pinning, streaming, sending, clarify and
approval answers); the thread, its bubbles, its composer and its header are new
code in `Conduit/Views/Elio/`.

## What is drawn

- `ElioRow` turns `AppState.messages` plus `streamingText` into four row kinds:
  user, agent, clarify, approval. Tool, reasoning, partial-as-working and system
  rows are dropped rather than styled.
- `ElioBubble`: user messages right in `Color.accentColor`, agent messages left
  on `secondarySystemBackground`, both with system type through `MarkdownText`,
  grouped runs sharing a tail corner. Agent bubbles are not width-capped on the
  trailing edge, so code blocks and lists get the room they need.
- `ElioTypingBubble`: three dots while a turn runs with no text yet. Static
  under Reduce Motion.
- `ElioClarifyCard` and `ElioApprovalCard`: the two decisions that would
  otherwise strand a turn. A free-text clarify is answered through the composer,
  whose prompt becomes "Answer Elio" while one is pending.
- `ElioComposer`: one growing `TextField`, send arrow inside the pill so the
  field never changes width as typing starts.
- `ElioChatScreen`: a `NavigationStack` with an inline "Elio" title and one
  trailing `square.and.pencil` button that calls `AppState.startNewChat()`,
  which starts a fresh session in the same profile. The thread is a
  `ScrollView` + `LazyVStack` on the system background, pinned to the bottom,
  with the composer as a bottom safe-area inset.

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
