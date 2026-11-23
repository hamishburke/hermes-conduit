# Updating the app while he is away from the Mac

He should be able to say "update the app" from his phone, in bed, and have it
happen. That means three things hold: the Mac stays awake and reachable, the
iPhone is reachable over the local network rather than a cable, and the signed
build runs somewhere that can use the signing key.

## Why a launchd agent and not SSH

`codesign` from an SSH session cannot reach the login key's private key and
fails `errSecInternalComponent` on the first framework it signs (WebRTC). No
amount of retrying, and no `sudo`, changes that: the key is only usable inside
the Mac's logged-in GUI session. So the signed build runs there, as a
LaunchAgent, and fedora asks for it by touching a file.

- Agent: `personal/elio-build-agent.sh`, installed by the plist
  `personal/com.hamishburke.elio-build.plist`.
- Trigger: `~/Developer/elio-iphone-build/.build-request`.
- Outcome: `~/Developer/elio-iphone-build/.build-status`, ending in
  `OK installed <version> (<n>) on <udid>` or `FAILED ...`.
- Watchdog output: `/tmp/elio-build-agent.err`.

`scripts/elio-install.sh --device` does the whole thing: rsync, simulator build,
write the version, touch the request, poll the status, print the outcome.

## One-time setup on the Mac

```sh
mkdir -p ~/Library/LaunchAgents
cp ~/Developer/elio-iphone-build/personal/com.hamishburke.elio-build.plist \
   ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.hamishburke.elio-build.plist
```

If `launchctl` says it is already loaded, `launchctl bootout` that label first,
or just log out and back in: everything in `~/Library/LaunchAgents` loads at
login.

## Staying awake and reachable

```sh
sudo pmset -a sleep 0 disksleep 0 womp 1
```

That keeps the Mac from sleeping while it is on power. On battery it still
sleeps, by design. Verify Tailscale and the phone's network link after it has
been idle a while, not just now.

## Signing team

The overlay clears `DEVELOPMENT_TEAM` on purpose, so the agent passes it back
on the command line: `XCE96GED42` (Wendy Burke, Personal Team). A free team
cannot register a device from the command line, so the device must have been
registered once by a Run from Xcode's UI. After that, installs work over the
wire; the phone shows up in `devicectl list devices` as
`transportType localNetwork, tunnelState connected`.

## What has been proven

- The agent fires from a `.build-request` touch and its output lands in
  `.build-status`.
- The simulator path builds and installs from fedora with no hands.
- The phone path: the first agent build failed at a zsh special variable
  (`status`), which is fixed; the signed build itself is the thing to watch on
  the next run.
