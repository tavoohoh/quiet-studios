#!/usr/bin/env bash
# App Store screenshots: iPhone 6.9" and iPad 13" × English/Spanish × light/dark.
# Runs the `Screenshots` scheme (Screenshots/ScreenshotTests.swift) on the `-demo` state
# and saves PNGs to AppStore/screenshots/<device>/<language>/<appearance>/NN-name.png.
# Spanish shots serve both es-MX and es-ES. The status bar language doesn't matter.
#
#   scripts/screenshots.sh                 # everything
#   scripts/screenshots.sh ipad            # only some devices (iphone, ipad)
#   LANGUAGES="es" APPEARANCES="dark" scripts/screenshots.sh iphone
#
# Simulators are created on first run ("QN iPhone 6.9", "QN iPad 13") and booted one at a time.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
OUT="${OUT:-$ROOT/AppStore/screenshots}"
# The design captures (scripts/design-screens.sh) run alone; the App Store set skips them.
FILTER=(-skip-testing:QuietNumbersScreenshots/ScreenshotTests/testDesignScreens)
[[ -n "${ONLY_TESTING:-}" ]] && FILTER=(-only-testing:"$ONLY_TESTING")
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

DEVICES=("${@:-iphone ipad}")
read -r -a DEVICES <<< "${DEVICES[*]}"
read -r -a LANGUAGES <<< "${LANGUAGES:-en es}"
read -r -a APPEARANCES <<< "${APPEARANCES:-light dark}"

RUNTIME="$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
ios = [r for r in json.load(sys.stdin)["runtimes"] if r["platform"] == "iOS" and r["isAvailable"]]
print(ios[-1]["identifier"])')"

simulator() { # name devicetype → udid (created if missing)
    local udid
    udid="$(xcrun simctl list devices -j | python3 -c "
import json, sys
for devices in json.load(sys.stdin)['devices'].values():
    for d in devices:
        if d['name'] == '$1' and d['isAvailable']: print(d['udid']); sys.exit()")"
    [[ -n "$udid" ]] || udid="$(xcrun simctl create "$1" "$2" "$RUNTIME")"
    echo "$udid"
}

# Runs the test once and copies its attachments into $1.
run_tests() { # destination-folder language appearance xcodebuild-destination
    local folder="$1" language="$2" appearance="$3" destination="$4"
    local result="$WORK/$(echo "${folder#"$OUT/"}" | tr / -).xcresult"
    echo "▸ $(basename "$(dirname "$(dirname "$folder")")")/$(basename "$(dirname "$folder")")/$(basename "$folder")"
    TEST_RUNNER_QN_LANGUAGE="$language" \
        xcodebuild test -project QuietNumbers.xcodeproj -scheme Screenshots \
        -destination "$destination" -resultBundlePath "$result" "${FILTER[@]}" -quiet >/dev/null
    rm -rf "$WORK/attachments" && mkdir -p "$folder"
    xcrun xcresulttool export attachments --path "$result" --output-path "$WORK/attachments" >/dev/null
    python3 - "$WORK/attachments" "$folder" <<'PY'
import json, shutil, sys, pathlib
source, target = map(pathlib.Path, sys.argv[1:])
for test in json.loads((source / "manifest.json").read_text()):
    for attachment in test["attachments"]:
        name = attachment["suggestedHumanReadableName"].split("_")[0]
        suffix = pathlib.Path(attachment["exportedFileName"]).suffix or ".png"
        shutil.copy(source / attachment["exportedFileName"], target / f"{name}{suffix}")
PY
}

shoot_simulator() { # folder-name simulator-name devicetype
    local udid
    udid="$(simulator "$2" "$3")"
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" >/dev/null
    xcrun simctl status_bar "$udid" override --time "2026-11-14T09:41:00.000-05:00" --dataNetwork wifi --wifiBars 3 \
        --cellularMode active --cellularBars 4 --batteryState discharging --batteryLevel 100
    for appearance in "${APPEARANCES[@]}"; do
        xcrun simctl ui "$udid" appearance "$appearance"
        for language in "${LANGUAGES[@]}"; do
            run_tests "$OUT/$1/$language/$appearance" "$language" "$appearance" "id=$udid"
        done
    done
    xcrun simctl status_bar "$udid" clear
    xcrun simctl shutdown "$udid"
}

for device in "${DEVICES[@]}"; do
    case "$device" in
        iphone) shoot_simulator iphone-6.9 "QN iPhone 6.9" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max ;;
        ipad) shoot_simulator ipad-13 "QN iPad 13" com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB ;;
        *) echo "Unknown device: $device (iphone, ipad)" >&2; exit 1 ;;
    esac
done

echo "Saved to ${OUT#"$ROOT/"}"
