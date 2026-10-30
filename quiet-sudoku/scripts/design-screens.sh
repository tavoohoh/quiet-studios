#!/usr/bin/env bash
# Every screen of the app in light and dark (English), for the design canvas's "Screens"
# page: AppStore/design-screens/iphone/en/<light|dark>/NN-name.png. Uses one simulator
# ("iPhone 17" unless SIMULATOR is set) and shuts it down at the end.
set -euo pipefail
cd "$(dirname "$0")/.."
NAME="${SIMULATOR:-iPhone 17}"
UDID=$(xcrun simctl list devices available | grep "    $NAME (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
BUNDLE=com.tavoohoh.quietsudoku
xcodebuild build -project QuietSudoku.xcodeproj -scheme QuietSudoku -destination "id=$UDID" -derivedDataPath build/dd -quiet
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" >/dev/null
xcrun simctl install "$UDID" "build/dd/Build/Products/Debug-iphonesimulator/Quiet Sudoku.app"
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3

SCREENS=(
  "01-home|-demo"
  "02-game|-demo -startGame -seedKey quiet-demo -level 1 -hint -demoClock 372"
  "03-summary|-demo -startGame -seedKey quiet-win -nearlyWon -hint -demoClock 268"
  "04-daily|-demo -open daily"
  "05-leaderboards|-demo -open leaderboards"
  "06-collection|-demo -open collection"
  "07-settings|-demo -open settings"
  "08-tutorial|-open tutorial"
)
for mode in light dark; do
  xcrun simctl ui "$UDID" appearance "$mode"
  OUT="AppStore/design-screens/iphone/en/$mode"
  mkdir -p "$OUT"
  for entry in "${SCREENS[@]}"; do
    name="${entry%%|*}"; args="${entry#*|}"
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
    # shellcheck disable=SC2086
    xcrun simctl launch "$UDID" "$BUNDLE" $args -AppleLanguages "(en)" -AppleLocale en_US >/dev/null
    sleep 6
    xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null 2>&1
  done
done
xcrun simctl ui "$UDID" appearance light
xcrun simctl status_bar "$UDID" clear
xcrun simctl shutdown "$UDID"
echo "Screens in AppStore/design-screens/iphone/en/"
