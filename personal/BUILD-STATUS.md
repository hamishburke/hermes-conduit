# Build and device evidence

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
