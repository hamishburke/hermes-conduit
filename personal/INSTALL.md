# Install a separate Elio development copy

These are pending Mac/device steps, not a record of successful installation.
Hamish selected his Mac and Apple Developer team. Keep the existing Conduit app
installed. This app uses `com.hamishburke.elio` and `elio://`, not Conduit's
bundle ID or link scheme.

1. On the Mac, use a current released Xcode with the iOS SDK and XcodeGen.
   Install XcodeGen with `brew install xcodegen` if missing.
2. Clone this branch into a new directory, never over a live Conduit checkout:

   ```sh
   git clone --branch personal/elio-one-thread \
     https://github.com/hamishburke/hermes-conduit.git elio-iphone
   cd elio-iphone
   xcodegen generate --spec personal/project.yml --project-root . --project .
   open Elio.xcodeproj
   ```

3. Select scheme **Conduit** in **Elio.xcodeproj**. The target keeps its upstream
   name/module to reuse tests; its built product is **Elio**. In the Conduit
   target's Signing & Capabilities, choose your own Apple Developer team and
   automatic signing. The personal overlay intentionally supplies no team and
   no upstream provisioning profile. Do not edit the root `project.yml` or switch
   to the upstream Conduit.xcodeproj.
4. First select an iPhone simulator and Build. Run the BotModeTests and
   ComposerDraftStoreTests in the personal configuration. Resolve any actual
   compiler/test failures before treating the source as an app build.
5. Select your connected iPhone, enable Developer Mode if iOS requires it, and
   Run. Confirm **Elio** appears beside **Conduit**, not as its replacement.
6. Pair Elio through the existing Conduit/Hermes pairing flow using your existing
   dashboard address. Do not copy Conduit's app container, device token, keychain
   or live plugin configuration. Confirm the first verified default canonical
   conversation is the intended Elio thread before sending private content.
7. Follow [ACCEPTANCE.md](ACCEPTANCE.md) on both simulator and phone. In particular,
   record the paused/self-corrected voice note, edit its transcript, and confirm
   nothing sends before a tap on Send.

For a command-line unsigned simulator compilation after project generation:

```sh
xcodebuild build -project Elio.xcodeproj -scheme Conduit \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/personal/DerivedData CODE_SIGNING_ALLOWED=NO
```

## Push is not enabled by this development overlay

Empty personal entitlements keep production app groups separate, but mean this
build cannot validate lock-screen notification delivery. A different bundle ID
is a different APNs topic. The existing production relay's credentials cannot
be assumed to deliver to it, and development-signing alone does not fix that.

Before a notification-capable build: provision the independent App ID and push
entitlement, confirm a compatible independently configured relay with the right
APNs team/topic/environment, and add the matching notification extension/app
group only in the personal build. Preserve the existing bridge and notification
routing rather than rewriting them. This step remains blocked, not silently
replaced by foreground WebSocket receipt or a fake Seen indicator.

Hosted compilation is also blocked by the account annotation recorded in
[BUILD-STATUS.md](BUILD-STATUS.md). No billing settings have been changed.

## What this Mac actually needed (2026-11-23)

Corrections to the steps above, from a real run on macOS 27.3 / Xcode 27.0
(27A266a), arm64. Nothing here has been installed on the iPhone yet.

- **No Homebrew on this Mac.** XcodeGen installs without it: take
  `xcodegen.zip` from the 2.48.0 release and run `xcodegen/bin/xcodegen` in
  place; it finds its `share/xcodegen` presets next to the binary.
- **Metal Toolchain ships separately with Xcode 26 and later.** Without it the
  first build stops at `error: cannot execute tool 'metal' due to missing Metal
  Toolchain`. Fix once per Xcode: `xcodebuild -downloadComponent MetalToolchain`.
- **Schemes are now explicit.** `personal/project.yml` declares `Elio` (the app)
  and `ElioTests` (the app plus `ConduitTests`). Use `-scheme Elio`, not
  `Conduit`. Declaring any `schemes:` block removes XcodeGen's implicit
  per-target schemes, which is also why `Conduit` no longer exists.
- **Signing.** The Mac holds a valid *Apple Development* certificate for team
  `8Y49AVBT79` but no Xcode account for it, so automatic signing for that team
  fails with `No Account for Team`. The account signed in to Xcode is a free
  Personal Team; a free team will not register a device from the command line
  (`Your team has no devices from which to generate a provisioning profile`),
  so the device has to be registered by a Run from Xcode's UI once. After that
  a profile appears in `~/Library/Developer/Xcode/UserData/Provisioning Profiles`.
- **`codesign` from an SSH session fails** with `errSecInternalComponent` on the
  embedded WebRTC framework: the private key is not usable outside the GUI
  security session. Command-line builds that need signing must therefore be run
  from a GUI session; unsigned `CODE_SIGNING_ALLOWED=NO` builds and simulator
  runs are unaffected.
- `xcodebuild -downloadPlatform iOS` installs the iOS 27.0 (24A434) simulator
  runtime, 8.05 GB; compiling needs only the SDK, running needs the runtime.
