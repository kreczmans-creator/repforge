#!/usr/bin/env bash
# WP 8 3b-9 (3B-ACC-01, WS5): migration timing on a real device.
#
# Usage (from app/):
#   tool/device_timing.sh android [adb-serial]
#   tool/device_timing.sh ios <device-udid-or-name>
#
# What it does:
#   1. records the device model and OS version (adb getprop / xcrun devicectl)
#      into build/device_timing/<platform>-<model>-<timestamp>/device.txt;
#   2. runs integration_test/migration_v8_timing_test.dart in PROFILE mode
#      (AOT, like a release build; debug-mode timings are not evidence) with
#      flutter drive and RUN_V8_TIMING=true: the D04 profile (5,000
#      exercises, 100,000 sets), 3 runs from an identical restored start and
#      a recovery/retry run, all in a temporary directory on the device;
#   3. keeps the driver's report (build/integration_response_data.json) and
#      the full log, and rebuilds the result JSON from the V8_TIMING_JSON
#      log lines as a second copy.
#
# The harness never opens the app's own database (it asserts this). It does
# install the app build on the device: use a device where that is fine.
# Requirements: Flutter 3.47.9 on PATH; Android: adb and USB debugging;
# iOS: Xcode 15+ (xcrun devicectl), a signing team set up for Runner, and
# the device unlocked and trusted. Profile mode does not run on emulators or
# simulators.
#
# Optional environment: V8_TIMING_REPS (default 3, minimum 3).
set -euo pipefail

platform="${1:-}"
device="${2:-}"
reps="${V8_TIMING_REPS:-3}"
here="$(cd "$(dirname "$0")/.." && pwd)"
cd "$here"

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
    sed -n '2,27p' "$0"
    exit 2
    ;;
esac

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
slug="$(echo "$platform-$device_model" | tr -cs 'A-Za-z0-9' '-' | cut -c1-60)"
out="build/device_timing/$slug-$stamp"
mkdir -p "$out"
{
  echo "platform: $platform"
  echo "device model: $device_model"
  echo "os: $device_os"
  echo "flutter device: $flutter_device"
  echo "started (UTC): $stamp"
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
    print(f"result: median {data['medianMs']} ms, worst {data['worstMs']} ms, "
          f"outcome {data['outcome']}, recovery {data['recovery']['outcome']}")
else:
    print(f"V8_TIMING_JSON incomplete: {len(parts)} of {total} chunks")
PY
echo "flutter drive exit code: $status; results in $out"
exit "$status"
