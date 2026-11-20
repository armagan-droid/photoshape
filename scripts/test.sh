#!/bin/zsh
# Runs `swift test` for every package under Packages/.
# Command Line Tools (without Xcode) do not find the Swift Testing macro plugin on their own,
# so we pass its path explicitly when it exists.
set -euo pipefail
ROOT="${0:A:h:h}"
PLUGIN_DIR="$(xcode-select -p)/usr/lib/swift/host/plugins/testing"
EXTRA=()
[[ -d "$PLUGIN_DIR" ]] && EXTRA=(-Xswiftc -plugin-path -Xswiftc "$PLUGIN_DIR")
for pkg in "$ROOT"/Packages/*/Package.swift; do
  dir="${pkg:h}"
  echo "▶ ${dir:t}"
  swift test --package-path "$dir" "${EXTRA[@]}" "$@"
done
