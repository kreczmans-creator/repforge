#!/usr/bin/env bash
# WP 8 3b-9 (3B-ACC-01, WS5): timing of the v7 -> v8 migration on a real
# device. Runs are not evidence until the owner records and accepts them
# (docs/device-timing.md).
#
# Usage (from app/):
#   tool/device_timing.sh android [adb-serial]
#   tool/device_timing.sh ios <device-udid-or-name>
#
# What it does:
#   1. records the device model, hardware and OS version (adb getprop /
#      xcrun devicectl), the commit and the Flutter version into
#      build/device_timing/<platform>-<model>-<timestamp>/device.txt;
#   2. runs integration_test/migration_v8_timing_test.dart in PROFILE mode
#      (AOT, like a release build; debug-mode timings are not evidence) with
#      flutter drive and RUN_V8_TIMING=true: the v7 D04 profile (5,000
#      exercises, 100,000 sets, 303 without a primary target) built on the
#      device, the registered v7 -> v8 migration through the app engine,
#      3 runs from an identical restored start, a recovery/retry run (failure
#      injected mid-step) and a seed run (bundled seed, R-30), all in a new
#      directory under the app's cache directory;
#   3. keeps the driver's report (build/integration_response_data.json) and
#      the full log, rebuilds the result JSON from the V8_TIMING_JSON log
#      lines as a second copy, and prints a summary.
#
# The harness never opens the app's own database (it asserts this). It does
# install the profile build of the app on the device: use a device where
# that is fine, and back up the app's data first if it holds real data.
# Requirements: Flutter 3.47.9 on PATH; python3; Android: adb and USB
# debugging; iOS: Xcode 15+ (xcrun devicectl), a signing team set up for
# Runner, and the device unlocked and trusted. Profile mode does not run on
# emulators or simulators. Bash 3.2 (macOS) or later.
#
# Optional environment: V8_TIMING_REPS (default 3, minimum 3).
set -euo pipefail

platform="${1:-}"
device="${2:-}"
reps="${V8_TIMING_REPS:-3}"
here="$(cd "$(dirname "$0")/.." && pwd)"
cd "$here"

case "$reps" in
  ''|*[!0-9]*) echo "V8_TIMING_REPS must be a number (got '$reps')" >&2; exit 2 ;;
esac
if [ "$reps" -lt 3 ]; then
  echo "V8_TIMING_REPS must be at least 3 (got $reps)" >&2
  exit 2
fi
extra_info=""

case "$platform" in
  android)
    # bash 3.2 (macOS) with `set -u` rejects "${empty[@]}", so the command
    # array always holds at least `adb`; -s is added only for a given serial.
    adb_cmd=(adb)
    if [[ -n "$device" ]]; then adb_cmd+=(-s "$device"); fi
    prop() { "${adb_cmd[@]}" shell getprop "$1" | tr -d '\r'; }
    manufacturer="$(prop ro.product.manufacturer)"
    model="$(prop ro.product.model)"
    release="$(prop ro.build.version.release)"
    sdk="$(prop ro.build.version.sdk)"
    soc="$(prop ro.soc.model)"
    [[ -z "$soc" ]] && soc="$(prop ro.board.platform)"
    abi="$(prop ro.product.cpu.abi)"
    ram_kb="$("${adb_cmd[@]}" shell cat /proc/meminfo | awk '/MemTotal/ {print $2}' | tr -d '\r')"
    device_model="$manufacturer $model (SoC $soc, $abi, RAM ${ram_kb} kB)"
    device_os="Android $release (API $sdk)"
    flutter_device="${device:-$("${adb_cmd[@]}" get-serialno | tr -d '\r')}"
    # Conditions at the start (notes field of the results template).
    battery="$("${adb_cmd[@]}" shell dumpsys battery | tr -d '\r' \
      | awk -F': ' '/ level:| temperature:| powered:| status:/ {printf "%s=%s ", $1, $2}' \
      | tr -s ' ')" || battery="not read"
    free_data="$("${adb_cmd[@]}" shell df -h /data | tr -d '\r' | tail -1)" \
      || free_data="not read"
    extra_info="battery at start: $battery
storage (/data): $free_data"
    ;;
  ios)
    if [[ -z "$device" ]]; then
      echo "iOS needs a device id: xcrun devicectl list devices" >&2
      exit 2
    fi
    info="$(mktemp)"
    xcrun devicectl device info details --device "$device" \
      --json-output "$info" >/dev/null
    read -r device_model device_os < <(python3 - "$info" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))["result"]
hw = d.get("hardwareProperties", {})
dev = d.get("deviceProperties", {})
cpu = hw.get("cpuType", {})
cpu = cpu.get("name", "?") if isinstance(cpu, dict) else cpu
# devicectl reports no RAM size; the chip comes from cpuType when present.
model = (f'{hw.get("marketingName", "?")} ({hw.get("productType", "?")}, '
         f'chip {cpu}, RAM not reported by devicectl)')
os_ = f'iOS {dev.get("osVersionNumber", "?")} ({dev.get("osBuildUpdate", "?")})'
print(model.replace(" ", "_"), os_.replace(" ", "_"))
PY
)
    device_model="${device_model//_/ }"
    device_os="${device_os//_/ }"
    rm -f "$info"
    flutter_device="$device"
    ;;
  *)
    sed -n '2,34p' "$0"
    exit 2
    ;;
esac

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
slug="$(echo "$platform-$device_model" | tr -cs 'A-Za-z0-9' '-' | cut -c1-60)"
# Seconds in the stamp plus the PID: two runs never share a folder.
out="build/device_timing/$slug-$stamp-$$"
mkdir -p "$out"
commit="$(git rev-parse HEAD 2>/dev/null)" || commit=""
[ -n "$commit" ] || commit="unknown"
if dirty="$(git status --porcelain 2>/dev/null)"; then
  dirty="$(printf '%s' "$dirty" | grep -c . || true) files"
else
  dirty="unknown"
fi
{
  echo "platform: $platform"
  echo "device model: $device_model"
  echo "os: $device_os"
  echo "flutter device: $flutter_device"
  echo "started (UTC): $stamp"
  echo "commit: $commit"
  echo "uncommitted changes: $dirty"
  echo "repetitions: $reps"
  if [ -n "$extra_info" ]; then echo "$extra_info"; fi
  flutter --version
} | tee "$out/device.txt"

rm -f build/integration_response_data.json
set +e
flutter drive --profile \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/migration_v8_timing_test.dart \
  -d "$flutter_device" \
  --dart-define=RUN_V8_TIMING=true \
  --dart-define=V8_TIMING_REPS="$reps" \
  --dart-define=DEVICE_MODEL="$device_model" \
  --dart-define=DEVICE_OS="$device_os" 2>&1 | tee "$out/drive.log"
status="${PIPESTATUS[0]}"
set -e

if [[ -f build/integration_response_data.json ]]; then
  cp build/integration_response_data.json "$out/report_data.json"
fi
python3 - "$out/drive.log" "$out/result_from_log.json" <<'PY' || true
import json, re, sys
parts = {}
total = 0
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    m = re.search(r"V8_TIMING_JSON (\d+)/(\d+) (.*)$", line.rstrip("\n"))
    if m:
        parts[int(m.group(1))] = m.group(3)
        total = int(m.group(2))
if total and len(parts) == total:
    data = json.loads("".join(parts[i] for i in range(1, total + 1)))
    json.dump(data, open(sys.argv[2], "w"), indent=2)
    if "runs" not in data:
        print(f"result: outcome {data.get('outcome')}, error {data.get('error')}")
        sys.exit(0)
    ref = data.get("hostReference", {})
    rec = data["recovery"]
    seed = data.get("seedRun", {})
    print(f"migration {data['migration']} (stand-in: {data['standIn']}); "
          f"evidence: {data['evidence']}")
    print(f"runs {[r['ms'] for r in data['runs']]} ms: median "
          f"{data['medianMs']} ms, worst {data['worstMs']} ms; SQLite "
          f"{data['sqliteVersion']}; size {data['dbBytesBefore']} -> "
          f"{data['dbBytesAfter']} bytes")
    print(f"recovery at {rec['injectedAt']}: failed attempt "
          f"{rec['failedAttemptMs']} ms, retry {rec['retryMs']} ms, "
          f"{rec['outcome']}; seed run {seed.get('ms')} ms, "
          f"{seed.get('outcome')}")
    print(f"start digest {data['profile']['startDigest']} "
          f"(host match: {ref.get('startMatches')}); end {data['endState']} "
          f"(host match: {ref.get('endMatches')})")
    print(f"outcome {data['outcome']}; failures {data.get('failures')}")
else:
    print(f"V8_TIMING_JSON incomplete: {len(parts)} of {total} chunks")
PY
echo "flutter drive exit code: $status; results in $out"
exit "$status"
