#!/usr/bin/env bash
# Every screen of the app in light and dark (English, iPhone 6.9"), for the design canvas's
# "Screens" page: AppStore/design-screens/iphone-6.9/en/<light|dark>/NN-name.png.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$PWD/AppStore/design-screens" LANGUAGES="en" \
    ONLY_TESTING="QuietNumbersScreenshots/ScreenshotTests/testDesignScreens" scripts/screenshots.sh iphone
