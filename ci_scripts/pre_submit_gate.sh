#!/usr/bin/env bash
set -euo pipefail

TARGET_PATH="${1:-Ida}"

if ! command -v greenlight >/dev/null 2>&1; then
  echo "error: greenlight CLI not found in PATH." >&2
  exit 127
fi

echo "==> Greenlight preflight target: ${TARGET_PATH}"

raw_output="$(greenlight preflight "${TARGET_PATH}" --format json 2>&1)"
printf '%s\n' "${raw_output}"

json_payload="$(printf '%s\n' "${raw_output}" | awk 'BEGIN { capture=0 } /^[[:space:]]*{/ { capture=1 } capture { print }')"

if [[ -z "${json_payload}" ]]; then
  echo "error: could not parse Greenlight JSON output." >&2
  exit 2
fi

critical_count="$(printf '%s\n' "${json_payload}" | sed -n 's/.*"critical":[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n 1)"
warn_count="$(printf '%s\n' "${json_payload}" | sed -n 's/.*"warns":[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n 1)"
info_count="$(printf '%s\n' "${json_payload}" | sed -n 's/.*"infos":[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n 1)"
passed_flag="$(
  JSON_PAYLOAD="${json_payload}" python3 - <<'PY'
import json
import os

try:
  data = json.loads(os.environ["JSON_PAYLOAD"])
except Exception:
  print("false")
  raise SystemExit(0)

summary = data.get("summary") or {}
print("true" if bool(summary.get("passed", False)) else "false")
PY
)"

critical_count="${critical_count:-0}"
warn_count="${warn_count:-0}"
info_count="${info_count:-0}"
passed_flag="${passed_flag:-false}"

if ! [[ "${critical_count}" =~ ^[0-9]+$ ]]; then
  echo "error: failed to read critical count from Greenlight output." >&2
  exit 2
fi

echo
echo "==> Gate summary: critical=${critical_count} warn=${warn_count} info=${info_count} passed=${passed_flag}"

if (( critical_count > 0 )); then
  echo "FAIL: resolve CRITICAL Greenlight findings before upload." >&2
  exit 1
fi

echo "PASS: no CRITICAL Greenlight findings for '${TARGET_PATH}'."
echo "Next: complete App Store Connect checklist and release build gate."
