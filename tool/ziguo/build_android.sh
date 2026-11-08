#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
"${FVM_BIN:-fvm}" flutter build apk --debug --no-tree-shake-icons \
  --dart-define=ZIGUO_CONTENT_PROBE=true "$@"
