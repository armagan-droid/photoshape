#!/bin/zsh
# Builds the iOS app and runs its UI tests in a simulator (simulated camera).
#   scripts/test-app.sh ["iPhone 17"]
set -euo pipefail
ROOT="${0:A:h:h}"
NAME="${1:-iPhone 17}"
UDID=$(xcrun simctl list devices available | grep -m1 "    $NAME (" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[[ -n "$UDID" ]] || { echo "simulator '$NAME' not found"; exit 2; }
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcodebuild -project "$ROOT/App/photoshape.xcodeproj" -scheme photoshape -destination "id=$UDID" test 2>&1 \
  | grep -E " error:|^Test Case.*(passed|failed)|\*\* (TEST|BUILD)" | sort -u
