#!/usr/bin/env bash
# Runs py-ballisticcalc's own test suite against dart-bclibc (through the bridge in tool/py_bridge)
# for ONE integration method, and writes the Dart VM coverage of lib/ that run produced.
#
#   scripts/ci/py-suite-coverage.sh <method> [out-dir]      # method: rk4|euler|verlet|rkck|dopri|tsitouras
#
# Output: <out-dir>/py-<method>.json  (raw VM coverage; the coverage workflow merges these with
# `format_coverage`, the Dart counterpart of `coverage combine`). Needs: dart, the `coverage` package
# (`dart pub global activate coverage`), python with py-ballisticcalc, dart_bclibc and pytest installed,
# and the py-ballisticcalc submodule.
set -euo pipefail

method="${1:?usage: py-suite-coverage.sh <method> [out-dir]}"
out_dir="${2:-coverage/raw}"
port="${VM_SERVICE_PORT:-8181}"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
mkdir -p "$out_dir"
out="$out_dir/py-$method.json"
rm -f "$out"

# The bridge is started (and stopped) by pytest, so it runs paused-on-exit with the VM service open and
# the collector, started first, waits for it to exit and then collects.
dart pub global run coverage:collect_coverage \
  --uri="http://127.0.0.1:$port/" \
  --connect-timeout=120 \
  --wait-paused --resume-isolates \
  --scope-output=bclibc \
  --out="$out" &
collector=$!

status=0
DART_BCLIBC_BRIDGE="dart run --pause-isolates-on-exit --disable-service-auth-codes --enable-vm-service=$port tool/py_bridge/bridge.dart" \
  python -m pytest py-ballisticcalc/tests --engine="dart_bclibc+$method" -p no:cacheprovider "${@:3}" || status=$?

wait "$collector"
test -s "$out" || { echo "no coverage was collected for $method" >&2; exit 1; }
exit "$status"
