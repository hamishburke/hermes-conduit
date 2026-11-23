#!/usr/bin/env bash
# Build the Elio app on his Mac from this checkout and put it on the phone.
# Run on fedora. Nothing here builds on Linux; the Mac does the compiling.
#
#   scripts/elio-install.sh            simulator only, never needs signing
#   scripts/elio-install.sh --device   simulator, then the phone
#
# The phone step needs the one-time Xcode Run that registers the device and
# writes its provisioning profile. A signed build from an SSH session fails
# (errSecInternalComponent) because the signing key is unusable outside the
# GUI security session; the script says so instead of pretending.
set -euo pipefail

mac="${ELIO_MAC:-hamishburke@hamishs-macbook-pro}"
clone="Developer/elio-iphone-build"
mode="${1:---sim}"
root=$(git rev-parse --show-toplevel)

tag=$(git ls-remote --tags --refs "git@github.com:hamishburke/hermes-conduit.git" 'elio-*' \
      | awk -F/ '{print $NF}' | sort -V | tail -1)
if [ -n "$tag" ]; then
    version="${tag#elio-}"
    number="${version##*.}"
else
    version="$(date +%Y.%m.%d).0"
    number="0"
fi
echo "building Elio $version ($number) from $(git rev-parse --short HEAD)"

rsync -az --exclude .git --exclude build --exclude Elio.xcodeproj \
    "$root/" "$mac:$clone/"

ssh "$mac" "cd ~/$clone && /tmp/xcodegen/bin/xcodegen generate --spec personal/project.yml --project-root . --project . >/dev/null"

set -o pipefail
if ! ssh "$mac" "cd ~/$clone && xcodebuild build -project Elio.xcodeproj -scheme Elio -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO MARKETING_VERSION=$version CURRENT_PROJECT_VERSION=$number" > /tmp/elio-sim.log 2>&1; then
    echo "simulator build failed; errors:" >&2
    grep -E " error: " /tmp/elio-sim.log | sort -u | head -20 >&2
    exit 1
fi
echo "simulator build ok"

ssh "$mac" "xcrun simctl install Elio-Sim ~/$clone/build/dd/Build/Products/Debug-iphonesimulator/Elio.app" || true

if [ "$mode" != "--device" ]; then
    echo "simulator updated. Pass --device to put it on the phone."
    exit 0
fi

if ! ssh "$mac" "cd ~/$clone && xcodebuild build -project Elio.xcodeproj -scheme Elio -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/dd-dev MARKETING_VERSION=$version CURRENT_PROJECT_VERSION=$number" > /tmp/elio-device.log 2>&1; then
    echo "device build needs a signing step only the GUI can do:" >&2
    grep -E " error: " /tmp/elio-device.log | sort -u | head -10 >&2
    cat >&2 <<'EOF'

Open Xcode on the Mac, choose the Elio scheme and the connected phone, press
Run once. That registers the device and writes the provisioning profile. After
that, re-running this script with --device installs over the wire.
EOF
    exit 1
fi

ssh "$mac" "cd ~/$clone && xcrun devicectl device install app --device '$(ssh "$mac" "xcrun devicectl list devices 2>/dev/null | awk '/connected/ {print \$1; exit}'")' build/dd-dev/Build/Products/Debug-iphoneos/Elio.app"

echo "installed $version on the phone"
