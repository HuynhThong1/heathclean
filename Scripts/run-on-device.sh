#!/bin/bash
#
# Build, install and launch on a physical iPhone, with the gateway configured.
#
# Why a script rather than a remembered command line: three things have to be
# passed every time or the build is quietly wrong, and none of them fails loudly.
#
#   1. GATEWAY_URL — unset means the app falls back to MockFoodRecognitionRepository.
#      The scan still "works", it just never talks to a model.
#   2. GATEWAY_API_KEY — unset means every /v1 call to a deployed gateway is 401.
#   3. -allowProvisioningUpdates — without it, a free Personal Team build fails
#      at signing rather than at compile time.
#
# The key is never written into the repo. It comes from the environment, or from
# the gateway checkout's .env, and lands only in the built app's Info.plist —
# which already carries $(GATEWAY_URL)/$(GATEWAY_API_KEY) placeholders for exactly
# this.
#
# The gateway is HTTPS on its own domain now, so there is no longer an ATS
# exception in Config/Info.plist to keep in step with this — pointing GATEWAY_URL
# at another https:// host needs no plist edit at all. A plain-http:// host still
# does, and the answer is a certificate rather than an exception, except on the
# local network, which NSAllowsLocalNetworking already covers.
#
# Usage:
#   Scripts/run-on-device.sh                       # deployed gateway, key from .env
#   GATEWAY_URL=http://192.168.1.20:8000 Scripts/run-on-device.sh
#   GATEWAY_API_KEY=… Scripts/run-on-device.sh
#   Scripts/run-on-device.sh --no-launch           # install only

set -euo pipefail
cd "$(dirname "$0")/.."

GATEWAY_URL="${GATEWAY_URL:-https://heathclean-gateway.chillcat.dev}"
GATEWAY_ENV="${GATEWAY_ENV:-$HOME/Projects/healthclean-gateway/.env}"
DERIVED="${DERIVED:-build/device}"
LAUNCH=1
[[ "${1:-}" == "--no-launch" ]] && LAUNCH=0

# The key: environment first, then the gateway's own .env. A localhost gateway
# needs none, so an empty key is a warning and not an error.
if [[ -z "${GATEWAY_API_KEY:-}" && -f "$GATEWAY_ENV" ]]; then
  GATEWAY_API_KEY="$(grep -E '^GATEWAY_API_KEY=' "$GATEWAY_ENV" | cut -d= -f2- | tr -d '"'"'"' \r' || true)"
fi
GATEWAY_API_KEY="${GATEWAY_API_KEY:-}"

if [[ -z "$GATEWAY_API_KEY" ]]; then
  echo "warning: no GATEWAY_API_KEY — fine for localhost, 401 on a deployed gateway" >&2
else
  echo "gateway: $GATEWAY_URL (key: ${#GATEWAY_API_KEY} chars)"
fi

# One paired, available device. `unavailable` here means unplugged, locked, or off
# the network — devicectl reports it either way, so say which.
DEVICE="$(xcrun devicectl list devices 2>/dev/null \
  | awk '/available \(paired\)|^.*available[^)]*$/ {print}' \
  | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' \
  | head -1 || true)"

if [[ -z "$DEVICE" ]]; then
  echo "error: no available device. Plug the iPhone in, unlock it, and trust this Mac." >&2
  xcrun devicectl list devices 2>/dev/null | tail -n +2 >&2
  exit 1
fi
echo "device: $DEVICE"

# `generic/platform=iOS` rather than the device id: it builds without waiting for
# the device to be reachable, so a locked phone costs an install and not a build.
xcodebuild \
  -scheme HeathFirst \
  -destination 'generic/platform=iOS' \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  GATEWAY_URL="$GATEWAY_URL" \
  GATEWAY_API_KEY="$GATEWAY_API_KEY" \
  build

APP="$DERIVED/Build/Products/Debug-iphoneos/HeathFirst.app"
xcrun devicectl device install app --device "$DEVICE" "$APP"

# A failed launch must not take the script with it. Under `set -e` it did, and it
# skipped the plist check below — the one step that exists to show whether the
# build settings substituted. Losing that to a transient tunnel error is backwards
# when the app is already installed. It still *reports* the failure, at the end and
# in the exit status: an app that did not start is worth knowing about, it is just
# not worth throwing the rest of the output away for.
#
# Observed once, and the reason for the retry: devicectl installed the app, then
# failed the launch with CoreDeviceError 10004 ("the process identifier of the
# launched application could not be determined"). Launching again a second later
# worked. It usually means the phone was locked or the developer tunnel had only
# just come up — not that the app died, which is why the message is worded to
# send you to the phone rather than to a crash log.
LAUNCH_STATUS=0
if [[ $LAUNCH == 1 ]]; then
  launch() {
    xcrun devicectl device process launch \
      --device "$DEVICE" --terminate-existing com.thonghm2.heathfirst
  }
  if ! launch; then
    echo "launch failed — retrying once (unlock the phone if it is locked)" >&2
    sleep 2
    launch || LAUNCH_STATUS=$?
  fi
fi

# What actually ended up in the bundle. Reads the built plist rather than echoing
# the arguments back, because a build setting that failed to substitute leaves the
# literal "$(GATEWAY_URL)" behind and that is worth seeing.
python3 - "$APP/Info.plist" <<'PY'
import plistlib, sys
p = plistlib.load(open(sys.argv[1], "rb"))
key = p.get("GATEWAY_API_KEY") or ""
ats = p.get("NSAppTransportSecurity", {}).get("NSExceptionDomains", {})
print("installed with:")
print("  GATEWAY_URL     ", p.get("GATEWAY_URL") or "(empty → mock provider)")
print("  GATEWAY_API_KEY ", f"{len(key)} chars" if key else "(empty)")
print("  ATS exceptions  ", ", ".join(ats) or "(none — plaintext HTTP will be blocked)")
PY

# Last, so it is the line left on screen, and non-zero so a caller that chains off
# this script does not carry on as though the app were running.
if [[ $LAUNCH_STATUS != 0 ]]; then
  echo >&2
  echo "warning: installed, but not launched (devicectl exit $LAUNCH_STATUS)." >&2
  echo "         Tap the app on the phone, or re-run:" >&2
  echo "         xcrun devicectl device process launch --device $DEVICE --terminate-existing com.thonghm2.heathfirst" >&2
  exit "$LAUNCH_STATUS"
fi
