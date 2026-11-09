#!/usr/bin/env bash
# Retry only transient Android/Gradle network failures on ephemeral CI runners.
# Permanent Dart, Kotlin or signing errors fail immediately.
set -euo pipefail

if [[ $# -ne 1 || ( "$1" != public && "$1" != qa ) ]]; then
  echo "Usage: bash tools/build_apk_with_network_retry.sh public|qa" >&2
  exit 64
fi

mode="$1"
: "${GITHUB_RUN_NUMBER:?A CI run number is required for monotonically increasing APK versionCode}"

command=(flutter build apk --release "--build-number=$GITHUB_RUN_NUMBER")
if [[ "$mode" == qa ]]; then
  command+=(--dart-define=ENABLE_QA_AUTOTAP=true)
fi

# Avoid logging keystore passwords: Flutter receives them only through the
# existing GitHub Actions secret environment, not command-line arguments.
log="$(mktemp "${RUNNER_TEMP:-/tmp}/balloon-$mode-gradle.XXXXXXXX.log")"
trap 'rm -f "$log"' EXIT

for attempt in 1 2 3; do
  echo "=== Balloon Burst $mode signed build attempt $attempt/3 ==="
  if "${command[@]}" 2>&1 | tee "$log"; then
    echo "PASS: $mode APK compiled on attempt $attempt."
    exit 0
  fi

  # A failed compile, missing secret, or non-network configuration problem
  # should not be masked by retries.
  if ! grep -Eqi \
      'timeout|timed out|Gateway Time-out|HTTP (429|502|503|504)|Received status code (429|502|503|504)|SocketTimeoutException|Connection reset|Could not GET|Network is unreachable|Temporary failure in name resolution|Downloading from .* failed' \
      "$log"; then
    echo "::error::Non-network $mode build failure: not retrying." >&2
    exit 1
  fi

  if (( attempt == 3 )); then
    echo "::error::Network download failure persisted across 3 $mode builds." >&2
    exit 1
  fi
  echo "::warning::Transient dependency download failure; retrying $mode build."
  sleep "$((attempt * 5))"
done
