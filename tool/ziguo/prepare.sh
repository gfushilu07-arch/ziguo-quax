#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
fvm_bin="${FVM_BIN:-fvm}"
"$fvm_bin" flutter pub get --enforce-lockfile
"$fvm_bin" dart run dart_pubspec_licenses:generate
"$fvm_bin" dart run intl_utils:generate
"$fvm_bin" dart run flutter_iconpicker:generate_packs --packs material
if [[ ! -x .venv/bin/python ]]; then python3 -m venv .venv; fi
.venv/bin/python -m pip install -r requirements.txt
if [[ -d /opt/homebrew/lib ]]; then
  export DYLD_FALLBACK_LIBRARY_PATH="/opt/homebrew/lib${DYLD_FALLBACK_LIBRARY_PATH:+:$DYLD_FALLBACK_LIBRARY_PATH}"
fi
# The upstream generator also rewrites documentation images. Preserve their
# existing bytes, including any developer edits; only runtime output is needed.
.venv/bin/python - <<'PY'
from pathlib import Path
import runpy
paths = [Path('assets/readme/icon.png'), Path('fastlane/metadata/android/en-US/images/icon.png')]
backups = {p: p.read_bytes() for p in paths if p.exists()}
try:
    runpy.run_path('generate_icons.py', run_name='__main__')
finally:
    for p, data in backups.items():
        p.write_bytes(data)
PY
