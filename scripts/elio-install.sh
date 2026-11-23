#!/usr/bin/env bash
# Build the Elio app on his Mac from this checkout and put it on the phone.
# Run on fedora. Nothing here builds on Linux; the Mac does the compiling.
#
#   scripts/elio-install.sh            simulator only, never needs signing
#   scripts/elio-install.sh --device   simulator, then the phone
#
# The phone build is not run over SSH. An SSH session cannot reach the signing
# key (errSecInternalComponent on the first framework), so the signed build and
# the install are done by a launchd agent inside the Mac's logged-in session:
# this script drops a request next to that agent and waits for its status.
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
    --exclude .build-status --exclude .build-request \
    "$root/" "$mac:$clone/"

if ! ssh "$mac" "cd ~/$clone && /tmp/xcodegen/bin/xcodegen generate --spec personal/project.yml --project-root . --project ." >/tmp/elio-gen.log 2>&1; then
    echo "project generation failed:" >&2
    tail -5 /tmp/elio-gen.log >&2
    exit 1
fi

if ! ssh "$mac" "cd ~/$clone && xcodebuild build -project Elio.xcodeproj -scheme Elio -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO MARKETING_VERSION=$version CURRENT_PROJECT_VERSION=$number" >/tmp/elio-sim.log 2>&1; then
    echo "simulator build failed; errors:" >&2
    grep -E " error: " /tmp/elio-sim.log | sort -u | head -20 >&2
    exit 1
fi
echo "simulator build ok"
ssh "$mac" "xcrun simctl install Elio-Sim ~/$clone/build/dd/Build/Products/Debug-iphonesimulator/Elio.app" >/dev/null 2>&1 || true

if [ "$mode" != "--device" ]; then
    echo "simulator updated. Pass --device to put it on the phone."
    exit 0
fi

# Ask the Mac's own session to do the signed build, then wait for its word.
ssh "$mac" "cd ~/$clone && printf '%s' '$version' > .build-version && printf '%s' '$number' > .build-number && rm -f .build-status && touch .build-request"

echo "asked the Mac to build and install; waiting for it"
for _ in $(seq 1 120); do
    sleep 5
    status=$(ssh "$mac" "tail -1 ~/$clone/.build-status 2>/dev/null || true")
    case "$status" in
        OK\ installed*)
            echo "$status"
            exit 0
            ;;
        FAILED*)
            echo "$status" >&2
            ssh "$mac" "tail -25 ~/$clone/.build-status" >&2
            exit 1
            ;;
    esac
done

echo "no answer from the Mac's build agent; its log:" >&2
ssh "$mac" "tail -20 ~/$clone/.build-status 2>/dev/null || cat /tmp/elio-build-agent.err" >&2
exit 1
