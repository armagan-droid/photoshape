#!/bin/zsh
# Spec 03 FR-009: every image that ships has a license record. Run before archiving with --release,
# which also refuses placeholder images (spec 03 açık soru 1). Exit 1 on any problem.
#   scripts/check-licenses.sh [--release]
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT/Packages/LookKit"
swift run -q look-tool check-licenses "$@"
