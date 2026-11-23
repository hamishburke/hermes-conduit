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
