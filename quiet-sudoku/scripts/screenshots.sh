#!/usr/bin/env bash
# App Store screenshots: iPhone 6.9" and iPad 13" × English/Spanish × light/dark, on the
# `-demo` state, to AppStore/screenshots/<device>/<language>/<appearance>/NN-name.png
# (scripts/store-images.py frames them). Spanish shots serve es-MX.
#
#   scripts/screenshots.sh                 # everything
#   scripts/screenshots.sh ipad            # only some devices (iphone, ipad)
#   LANGUAGES="es" APPEARANCES="dark" scripts/screenshots.sh iphone
#
# Simulators are created on first run ("QSu iPhone 6.9", "QSu iPad 13"), booted one at a
# time and shut down by udid. Don't run it while another app is capturing.
set -euo pipefail
cd "$(dirname "$0")/.."
BUNDLE=com.tavoohoh.quietsudoku
APP="build/dd/Build/Products/Debug-iphonesimulator/Quiet Sudoku.app"

DEVICES=("${@:-iphone ipad}")
read -r -a DEVICES <<< "${DEVICES[*]}"
read -r -a LANGUAGES <<< "${LANGUAGES:-en es}"
read -r -a APPEARANCES <<< "${APPEARANCES:-light dark}"

# name|seconds to wait|launch arguments (the summary sheet comes after the win animation).
SCREENS=(
  "01-game|8|-demo -completeToday -startGame -seedKey quiet-store -level 1 -filled 22 -hint -demoClock 372"
  "02-daily|8|-demo -completeToday -open daily"
  "03-leaderboards|8|-demo -completeToday -open leaderboards"
  "04-collection|8|-demo -completeToday -open collection"
  "05-win|16|-demo -completeToday -startGame -seedKey quiet-win -nearlyWon -hint -demoClock 268"
  "06-home|8|-demo -completeToday"
)

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

xcodebuild build -project QuietSudoku.xcodeproj -scheme QuietSudoku -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath build/dd -quiet

shoot() { # folder-name simulator-name devicetype
    local udid
    udid="$(simulator "$2" "$3")"
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" >/dev/null
    xcrun simctl install "$udid" "$APP"
    xcrun simctl status_bar "$udid" override --time 9:41 --dataNetwork wifi --wifiBars 3 \
        --cellularMode active --cellularBars 4 --batteryState discharging --batteryLevel 100
    # A first launch on a fresh simulator is slow and iOS shows its own banners: warm up.
    xcrun simctl launch "$udid" "$BUNDLE" -demo >/dev/null
    sleep 15
    for appearance in "${APPEARANCES[@]}"; do
        xcrun simctl ui "$udid" appearance "$appearance"
        for language in "${LANGUAGES[@]}"; do
            local out="AppStore/screenshots/$1/$language/$appearance" locale
            [[ "$language" == es ]] && locale=es_MX || locale=en_US
            mkdir -p "$out"
            echo "▸ $out"
            for entry in "${SCREENS[@]}"; do
                local name wait args
                IFS='|' read -r name wait args <<< "$entry"
                xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
                # shellcheck disable=SC2086
                xcrun simctl launch "$udid" "$BUNDLE" $args -AppleLanguages "($language)" -AppleLocale "$locale" >/dev/null
                sleep "$wait"
                xcrun simctl io "$udid" screenshot "$out/$name.png" >/dev/null 2>&1
            done
        done
    done
    xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
    xcrun simctl ui "$udid" appearance light
    xcrun simctl status_bar "$udid" clear
    xcrun simctl shutdown "$udid"
}

for device in "${DEVICES[@]}"; do
    case "$device" in
        iphone) shoot iphone-6.9 "QSu iPhone 6.9" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max ;;
        ipad) shoot ipad-13 "QSu iPad 13" com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB ;;
        *) echo "Unknown device: $device (iphone, ipad)" >&2; exit 1 ;;
    esac
done
echo "Saved to AppStore/screenshots/"
