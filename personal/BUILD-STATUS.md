# Build and device evidence

## Purpose-built thread, 2026-11-23 23:15

Xcode 27.0, iOS 27.0 SDK, XcodeGen 2.48.0, simulator `Elio-Sim` (iOS 27,
iPhone 17 Pro class). Working tree of `personal/elio-one-thread` plus the
uncommitted thread rewrite.

- Unsigned simulator build: **BUILD SUCCEEDED** on every iteration
  (`xcodebuild build -destination generic/platform=iOS Simulator`).
- Installed and launched with `-ElioLook`, the DEBUG sample-thread argument.
  Screenshots `~/elio-shots/21-ref-light.png` and `22-ref-dark.png` are the
  current reference-matching build; `18-ax.png` is the same screen at
  accessibility-extra-large, and `20-login.png` is the unpaired first-run
  screen with no `-ElioLook`.
- Seen in the screenshots: white/black opaque bar with a centred "Elio" and one
  trailing compose button; grey incoming bubbles, blue outgoing bubbles with
  white text, uniform rounding and tighter runs from one speaker; a "Seen"
  receipt under the last sent message; a Markdown code block inside a bubble;
  a clarify question with one bubble per choice; one growing composer reading
  "Message Elio".
- Not done: install on the physical iPhone, pairing, a real send, streaming,
  VoiceOver, Reduce Motion, iPad, and the top-of-thread grouping. The simulator
  has no pairing, so `-ElioLook` feeds fixed rows; it proves layout, not the
  data path.

## Mac compile and simulator run, 2026-11-23

Head `13c43a0` (then the two overlay build commits) on `personal/elio-one-thread`,
Xcode 27.0 (27A266a), iOS 27.0 SDK, macOS 27.3, arm64, XcodeGen 2.48.0.

- Unsigned device build for `generic/platform=iOS`: **BUILD SUCCEEDED**, after
  installing Apple's separate Metal Toolchain (`xcodebuild -downloadComponent
  MetalToolchain`); without it the build stops at `error: cannot execute tool
  'metal' due to missing Metal Toolchain`.
- Unsigned simulator build for `generic/platform=iOS Simulator`: **BUILD SUCCEEDED**.
- Installed and launched on an iPhone 17 Pro simulator (iOS 27 runtime). First
  screen is RootView's existing connection screen: app title, dashboard address
  field, Paste/Scan Code, Advanced, Continue. No tab bar, no bot/group picker,
  no work view.
- Unit tests, `-scheme ElioTests`, simulator: **362 executed**. `ComposerDraftStoreTests`
  55/55 passed. `BotModeTests` 307 executed with **70 failures**, all in
  notification/deep-link routing: the personal gate answers
  `Elio only opens its pinned conversation…` where upstream routes the target or
  returns a retryable `unverified`. Not yet triaged into "deliberate personal
  divergence" versus "regression"; the retryable case is the one to look at first
  (`testUnverifiableWorkspaceIsRetriedNotRefused`).
- The umbrella headers in the build log ("Could not find test host") were the
  overlay's own two defects, now fixed in `personal/project.yml`: XcodeGen derives
  `TEST_HOST` from the target name, so the product rename to `Elio` broke it, and
  declaring a `schemes:` block removes the implicit per-target schemes.

Not yet done: signing, install on the physical iPhone, push, any on-device feel
check, screen recording, VoiceOver/Reduce Motion runs.

## Minimal comparison commit


`8b907adca30d59944f16758aeae7a858e6801267` is the minimal one-thread pass,
from upstream `47d3f9e22d4245de8aedd78174068b8e5dfe033c`.
It is not an installed or Swift-compiled build.

Parent verification on Linux:

- Full upstream Python tooling discovery: `Ran 713 tests in 82.171s`,
  `OK (skipped=1)`, using `CONDUIT_CI_SKIP_BASH_WRAPPER_TESTS=1`.
- Bounded feature-map/localization/planner/mac-dev tooling suites:
  `Ran 242 tests in 5.496s`, `OK`.
- Localization: 9,933 call sites resolve, all catalog keys translated in
  every shipped language. Personal-only new copy is explicitly English.
- Test planner: validation OK, 224 unit classes and 9 UI classes; existing
  class-capacity warning remains. New Swift tests extend existing classes.
- Sheet and transcript environment checks: pass.
- Feature-map full CLI attempt reached the 120-second limit (exit 124).
  Local-only verification using the checker's production parser found 214
  entries, 3,851 local path references and zero problems. Remote notifier/desktop
  references are NOT verified by that result.
- `git diff --check`: pass.
- Static review found two issues, corrected before the minimal commit:
  explicit Retry needed a roster refresh, and Xcode selection needed sudo.

These are tooling/static checks, not a run of Swift unit tests or the app.

## Hosted compile attempt

Exact head: `8b907adca30d59944f16758aeae7a858e6801267`

Run: https://github.com/hamishburke/hermes-conduit/actions/runs/45121581647

Check run: `137516333861`, `simulator-build`, failed before any step started.
The GitHub annotation was:

> The job was not started because your account is locked due to a billing issue.

No compiler, XcodeGen, simulator, signing or installation ran in this attempt.
Billing was not changed. Further source work cannot resolve account eligibility.
Do not describe this as a source compile failure, approval hold or passing build.

## Device route

Hamish chose his Mac and Apple Developer team for a separately signed copy.
The MacBook was offline at discovery. Linux has no Swift, Xcode or simulator;
the connected iPhone's Conduit chat tools are not an app installation/debugging
channel. No iPhone feel check or screen recording has been performed.

The development overlay's empty entitlements intentionally do not enable APNs.
An independent App ID, provisioning, APNs topic/credentials and compatible relay
configuration are needed before the lock-phone reply test can pass. Do not change
production Conduit's bundle, plugin, relay or settings to remove this blocker.

The remaining behavioural checklist is in [ACCEPTANCE.md](ACCEPTANCE.md).
