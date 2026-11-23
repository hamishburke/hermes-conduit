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
