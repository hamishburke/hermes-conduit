#!/bin/zsh
# Runs a signed Elio build and installs it on the phone.
#
# This is not run over SSH. It is run by launchd inside the logged-in GUI
# session, which is the only place codesign can reach the signing key: an SSH
# session cannot, and fails with errSecInternalComponent on the first framework.
#
# Trigger: the file .build-request beside this script. fedora writes it after
# rsyncing the tree. Output and outcome go to .build-status.
set -uo pipefail

root="$HOME/Developer/elio-iphone-build"
cd "$root" || exit 1
log="$root/.build-status"
team="${ELIO_TEAM:-XCE96GED42}"
version=$(cat "$root/.build-version" 2>/dev/null || echo "0.0.0")
number=$(cat "$root/.build-number" 2>/dev/null || echo "0")

echo "started $(date -u +%Y-%m-%dT%H:%M:%SZ) version $version ($number)" > "$log"

if ! /tmp/xcodegen/bin/xcodegen generate --spec personal/project.yml \
        --project-root . --project . >>"$log" 2>&1; then
    echo "FAILED project generation" >> "$log"
    exit 1
fi

if ! xcodebuild build -project Elio.xcodeproj -scheme Elio -configuration Debug \
        -destination 'generic/platform=iOS' -derivedDataPath build/dd-dev \
        DEVELOPMENT_TEAM="$team" MARKETING_VERSION="$version" \
        CURRENT_PROJECT_VERSION="$number" >>"$log" 2>&1; then
    echo "FAILED build" >> "$log"
    grep -E " error: |errSec" "$log" | sort -u | tail -5 >> "$log"
    exit 1
fi

app="$root/build/dd-dev/Build/Products/Debug-iphoneos/Elio.app"
if [ ! -d "$app" ]; then
    echo "FAILED no app at $app" >> "$log"
    exit 1
fi

xcrun devicectl list devices --json-output /tmp/elio-devices.json >/dev/null 2>&1
udid=$(python3 - <<'PY'
import json
try:
    data = json.load(open("/tmp/elio-devices.json"))
except Exception:
    raise SystemExit(0)
for device in data.get("result", {}).get("devices", []):
    props = device.get("deviceProperties", {})
    link = device.get("connectionProperties", {})
    if props.get("name", "").startswith("Hamish") and link.get("tunnelState") == "connected":
        print(device.get("identifier", ""))
        break
PY
)

if [ -z "${udid:-}" ]; then
    echo "FAILED no connected iPhone" >> "$log"
    exit 1
fi

if xcrun devicectl device install app --device "$udid" "$app" >>"$log" 2>&1; then
    echo "OK installed $version ($number) on $udid" >> "$log"
else
    echo "FAILED install" >> "$log"
    exit 1
fi
