# Bounded review fixes — 2026-11-23

Fixed the three errors in the final correctness/UX review JSONs and the
320pt dictation layout concern. Workspace draft provenance is separate from
the pinned bot profile. Same-registry reconnect validation retains mounted
ChatView and carries authoritative aliases through the existing same-chat
composer handoff. Different lineage or scope/pin mismatch invalidates proof.
Dictation/accessibility layout gives the editor its own row; dictation labels
inherit accessibility text sizes, while glyphs alone are capped.

One regression method was added to existing `BotModeTests`, and existing
policy assertions were extended. It uses actual AppState composer key/owner
APIs with workspace `work`, pinned bot `personal`, an empty ordinary catalog,
a persistence round trip, changed runtime alias, and refusal across workspace,
profile, dashboard, server and canonical-lineage changes. It also checks the
production display/same-chat policies during the ordinary resume callback.
The test harness is now visible to its same-class extension in the other file.
All XCTest additions remain authored but **not run**. No tests, Swift/Xcode,
network, services, git mutations, commits or pushes were run in this fix pass.
The parent-owned `BUILD-STATUS.md` and `INSTALL.md` were left untouched.

Bounded static commands run in this fix pass (all exit 0):

```sh
timeout 45s python3 scripts/check-l10n-coverage.py --repo-root .
timeout 45s python3 scripts/check-sheet-environment.py --repo-root .
timeout 45s python3 scripts/check-transcript-environment.py --repo-root .
timeout 45s python3 scripts/check-fixed-text-sizes.py --repo-root .
timeout 45s python3 scripts/check-hand-written-equality.py --repo-root .
timeout 45s python3 scripts/plan-tests.py validate --repo-root . --baseline scripts/test-timings.json
git diff --check
```

Results: 9933 localization sites resolve with complete shipped-language
coverage; 823 Swift files pass sheet environments; 42 transcript environment
keys pass; 723 Swift files pass fixed-text-size checks; no new hand-written
equality (15 existing, 10 files). Planner: `discovered 224 unit + 9 UI test
classes (0 warnings)` and `plan validation OK`. Its existing max-lanes (8)
capacity warning remains. `git diff --check` is clean. No feature-map CLI or
remote lookup was run. These are source checks only: compile, device rendering,
320pt/large Dynamic Type, keyboard and live dictation behavior remain unverified.
The earlier PASS2/PASS1 validation records below describe earlier runs.

---

# PASS2 local validation — 2026-11-23

PASS1 comparison/HEAD remains `8b907adca30d59944f16758aeae7a858e6801267`.
PASS2 is uncommitted. No workflow edits, git mutations, push, service/live
install, package or network bridge changes were made. The parent-owned
`.github/workflows/elio-personal.yml` was not triggered. A concurrently supplied
untracked `personal/BUILD-STATUS.md` was left alone.

Linux has no Swift or Xcode (`command -v swift` and `command -v xcodebuild`
returned no path). No Swift compilation, XCTest, simulator/device, signing,
push, Dynamic Type, VoiceOver or visual interaction success is claimed.
Twelve PASS2 XCTest methods extend the existing `BotModeTests` and
`ComposerDraftStoreTests` classes and are **not run**. They exercise production
canonical notification/draft-owner/display policy and store persistence APIs,
including separate-instance round trips, coalescing, attachment/reply retention,
failed restore, send removal, stale submission buckets, scope isolation,
capacity/owner migration and clear/signout fences. The personal overlay also
defines ELIO_PERSONAL for its unit-test target; no upstream test target changes.

Commands actually run (all exit 0):

```sh
PYTHONPATH=scripts/tests timeout 45s python3 -m unittest \
  test_check_feature_map test_check_l10n_coverage test_plan_tests test_mac_dev_build
python3 scripts/check-l10n-coverage.py --repo-root .
python3 scripts/check-sheet-environment.py --repo-root .
python3 scripts/check-transcript-environment.py --repo-root .
python3 scripts/check-fixed-text-sizes.py --repo-root .
python3 scripts/check-hand-written-equality.py --repo-root .
python3 scripts/plan-tests.py validate --repo-root . --baseline scripts/test-timings.json
git diff --check
```

The bounded Python run reported:

```text
Ran 242 tests in 5.643s

OK
```

Static gates reported 9933 resolved localization call sites, complete shipped
language coverage, 823 Swift files checked for sheet environments, 42 transcript
environment keys, 723 Swift files checked for fixed text sizes and no new
hand-written equality. The planner reported `discovered 224 unit + 9 UI test
classes (0 warnings)` and `plan validation OK`. Its existing max-lanes warning
remains; no class or infrastructure capacity was added. `git diff --check`
produced no output.

The local-only feature-map check reproduced below in the PASS1 record was rerun
against PASS2 and reported:

```text
Feature map local-only: 214 entries, 3858 local paths, 0 problems; sibling network lookups skipped.
```

These checks validate repository rules and Python tooling, not Swift types or
iOS behavior. Review confirmed the runtime changes are selected by ELIO_PERSONAL;
the shared save API only applies its new clear-count check in that build. No
claim of byte-for-byte disabled-source equivalence is made for PASS2's small
shared value-forwarding refactors.

Cold offline history remains an explicit gap: SavedBotChatCopy supplies bot and
session ids per dashboard/profile, but no normalized server + canonical-pin
proof. ConversationIdentityIndex is runtime evidence, not a persisted canonical
pin registry. No saved session pointer was promoted to authority. Draft records
remain durable and independent of whether the transcript is exposed. Coalescing
has a 300 ms abrupt-termination window before explicit lifecycle/send flushes.
Historical notification aliases must be present in authoritative canonical
lookup; unknown ids fail closed.

Mac follow-up: generate the personal overlay and compile it, then run both
`BotModeTests` and `ComposerDraftStoreTests` in the personal configuration.
Run `personal/ACCEPTANCE.md` on simulator/iPhone. The parent can collect compiler
evidence through the existing workflow if its runner starts; no result is
claimed here.

---

# PASS1 local validation — 2026-11-23

Source/static validation on Linux only. No Swift, Xcode, XcodeGen, simulator,
device, signing or APNs success is claimed. The seven new XCTest methods in
`ConduitTests/BotModeTests+Elio.swift` were **not executed**. No network lookup,
git mutation, commit, push or contact was performed for this implementation.

The existing personal overlay/docs were extended. The concurrently supplied
`personal/ACCEPTANCE.md` and `.github/workflows/elio-personal.yml` were left
untouched; the workflow was not triggered or verified here.

## Bounded Python tests

Command (exit 0, completed within the 45-second bound):

```sh
PYTHONPATH=scripts/tests timeout 45s python3 -m unittest \
  test_check_feature_map test_check_l10n_coverage test_plan_tests test_mac_dev_build
```

Exact unittest result footer:

```text
----------------------------------------------------------------------
Ran 242 tests in 5.525s

OK
```

The planner tests also emitted their existing max-lane capacity warnings. The
whole scripts unittest discovery was deliberately not run.

## Static gates

These commands all exited 0:

```sh
python3 scripts/check-l10n-coverage.py --repo-root .
python3 scripts/check-sheet-environment.py --repo-root .
python3 scripts/check-transcript-environment.py --repo-root .
python3 scripts/check-fixed-text-sizes.py --repo-root .
python3 scripts/check-hand-written-equality.py --repo-root .
python3 scripts/plan-tests.py validate --repo-root . --baseline scripts/test-timings.json
git diff --check
```

Exact coverage/environment/style output:

```text
Languages: source en; shipped de, es, fr, id, it, ja, ko, pl, pt-BR, ru, tr, zh-Hans, zh-Hant; drafts none.
OK: 9933 localizable call sites all resolve in the catalog.
OK: every catalog key is translated in every shipped language (de, es, fr, id, it, ja, ko, pl, pt-BR, ru, tr, zh-Hans, zh-Hant) with type-matched placeholders.
OK: every sheet, full-screen cover and popover injects the environment objects its content reads (823 Swift files).
OK: every Conduit environment key reaches the transcript rows or is set inside them (42 keys).
OK: no fixed text sizes or .font( text styles in 723 Swift files.
OK: no new hand-written `static func ==` (15 left, in 10 files).
```

The plan validator reported `discovered 224 unit + 9 UI test classes (0 warnings)`
and ended with `plan validation OK`. Its separate existing warning says the unit
lane count is at max_lanes (8); extending BotModeTests added no test class.
`git diff --check` printed nothing. It checks tracked diffs; the new files were
also inspected directly.

A local source projection selected the disabled side of only the new personal
conditionals and compared each modified shared Swift file byte-for-byte against
`git show HEAD:<path>` (read-only). Exact result:

```text
ELIO_PERSONAL disabled: all three modified shared Swift files match HEAD exactly after flag projection.
```

This checks the source isolation boundary; it is not a Swift compiler check.

For the feature map, imported the existing checker's `shape_problems`, `paths`
and `entries`, checked every local path with pathlib, and deliberately skipped
notifier/desktop paths rather than running the CLI's network lookups. Exact
result:

```text
Feature map local-only: 214 entries, 3851 local paths, 0 problems; sibling network lookups skipped.
Personal bundle name fallback and empty entitlements: OK.
```

The second check parsed both plists with Python's standard-library plistlib:
CFBundleName is `$(PRODUCT_NAME)`, the overlay's PRODUCT_NAME is Elio, there is
no overriding CFBundleDisplayName/CFBundleName localization, and the personal
entitlements dictionary is empty. Project generation and the built bundle's
actual processed plist still require Mac verification.

The precise feature-map local check can be repeated without network:

```sh
python3 - <<'PY'
import importlib.util
from pathlib import Path
spec = importlib.util.spec_from_file_location('feature_map', 'scripts/check-feature-map.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
s = Path('docs/FEATURE_MAP.md').read_text()
problems = m.shape_problems(s)
local = [(n, p) for n, p in m.paths(s) if not p.startswith(tuple(m.SIBLING_REPOS))]
for n, p in local:
    if not Path(p).exists():
        problems.append((n, f'missing local path: {p}'))
for n, p in problems:
    print(f'{n}: {p}')
print(f'Feature map local-only: {len(m.entries(s))} entries, {len(local)} local paths, {len(problems)} problems; sibling network lookups skipped.')
raise SystemExit(bool(problems))
PY
```

Mac follow-up: generate the personal overlay, build the Conduit scheme in
Elio.xcodeproj, then run the `BotModeTests` XCTest class and the manual checklist
in ACCEPTANCE.md. The new shell is functional source, but these local Python
checks cannot establish that it compiles or behaves correctly on iOS.

## Mac results that supersede the note above — 2026-11-23

The overlay compiles: unsigned device and simulator builds both report
`BUILD SUCCEEDED` on Xcode 27.0. The two defects found there are fixed in
`personal/project.yml` (TEST_HOST after the product rename, and the schemes
block that replaced the implicit per-target schemes).

`xcodebuild test -scheme ElioTests` on an iPhone 17 Pro simulator executed 362
tests. `ComposerDraftStoreTests` 55/55 passed. `BotModeTests`: 307 executed,
**70 failures**, unchanged before and after `987d64d`.

What the 70 actually are: each one asserts upstream routing for a notification
that names a profile other than the pinned one (for example
`ConduitNotificationTarget(profile: "analyst")` against `activeProfile
"default"`), and the personal gate refuses that target by design because this
build has no workspace UI to open it in. The tests are compiled with
`ELIO_PERSONAL`, so they assert a routing the personal build deliberately does
not do.

`987d64d` was written to make an *unproven* target retryable instead of
dead-ending; re-running the suite showed the identical 70 failures, so that
commit changed no test outcome. It is kept because the semantics are still
right (a target that names this pin but whose ids are not proven yet now
returns `unverified`), but it is **not** evidence of a fix and no test covers it.

Therefore: not one of the 70 is reconciled yet. The next step is personal
expectations for the routing assertions (a personal variant per test, or the
flag off for the upstream half of the class), not further behaviour changes.
