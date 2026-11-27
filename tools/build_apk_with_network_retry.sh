#!/usr/bin/env bash
# Retry only transient Android/Gradle network failures on ephemeral CI runners.
# Permanent Dart, Kotlin or signing errors fail immediately.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: bash tools/build_apk_with_network_retry.sh public|qa|qa-glow|qa-aura-v2|qa-frame-diag|qa-frame-phases|qa-android-presentation|qa-ui-build|qa-frame-scheduler|qa-wall-clock|qa-frame-request|qa-native-handoff|qa-clock-epoch|qa-app-frame" >&2
  exit 64
fi
if [[ "$1" != public && "$1" != qa && "$1" != qa-glow && "$1" != qa-aura-v2 && "$1" != qa-frame-diag && "$1" != qa-frame-phases && "$1" != qa-android-presentation && "$1" != qa-ui-build && "$1" != qa-frame-scheduler && "$1" != qa-wall-clock && "$1" != qa-frame-request && "$1" != qa-native-handoff && "$1" != qa-clock-epoch ]]; then
  echo "Usage: bash tools/build_apk_with_network_retry.sh public|qa|qa-glow|qa-aura-v2|qa-frame-diag|qa-frame-phases|qa-android-presentation|qa-ui-build|qa-frame-scheduler|qa-wall-clock|qa-frame-request|qa-native-handoff|qa-clock-epoch|qa-app-frame" >&2
  exit 64
fi

mode="$1"
: "${GITHUB_RUN_NUMBER:?A CI run number is required for monotonically increasing APK versionCode}"

command=(flutter build apk --release "--build-number=$GITHUB_RUN_NUMBER")
if [[ "$mode" == qa || "$mode" == qa-glow || "$mode" == qa-aura-v2 || "$mode" == qa-frame-diag || "$mode" == qa-frame-phases || "$mode" == qa-android-presentation || "$mode" == qa-ui-build || "$mode" == qa-frame-scheduler || "$mode" == qa-wall-clock || "$mode" == qa-frame-request || "$mode" == qa-native-handoff || "$mode" == qa-clock-epoch || "$mode" == qa-app-frame ]]; then
  command+=(--dart-define=ENABLE_QA_AUTOTAP=true)
fi
if [[ "$mode" == qa-glow ]]; then
  command+=(--dart-define=TJ45B_GLOW_GRADIENT=true)
fi
if [[ "$mode" == qa-aura-v2 || "$mode" == qa-frame-diag || "$mode" == qa-frame-phases || "$mode" == qa-android-presentation || "$mode" == qa-ui-build || "$mode" == qa-frame-scheduler || "$mode" == qa-wall-clock || "$mode" == qa-frame-request || "$mode" == qa-native-handoff || "$mode" == qa-clock-epoch || "$mode" == qa-app-frame ]]; then
  command+=(--dart-define=TJ45B_GLOW_AURA_V2=true)
fi
if [[ "$mode" == qa-frame-diag || "$mode" == qa-frame-phases || "$mode" == qa-android-presentation || "$mode" == qa-ui-build || "$mode" == qa-frame-scheduler || "$mode" == qa-wall-clock || "$mode" == qa-frame-request || "$mode" == qa-native-handoff || "$mode" == qa-clock-epoch || "$mode" == qa-app-frame ]]; then
  command+=(--dart-define=TJ45D_FRAME_DIAG=true)
fi
if [[ "$mode" == qa-frame-phases || "$mode" == qa-android-presentation || "$mode" == qa-ui-build || "$mode" == qa-frame-scheduler || "$mode" == qa-wall-clock || "$mode" == qa-frame-request || "$mode" == qa-native-handoff || "$mode" == qa-clock-epoch || "$mode" == qa-app-frame ]]; then
  command+=(--dart-define=TJ45E_FRAME_PHASES=true)
fi
if [[ "$mode" == qa-android-presentation || "$mode" == qa-ui-build || "$mode" == qa-frame-scheduler || "$mode" == qa-wall-clock || "$mode" == qa-frame-request || "$mode" == qa-native-handoff || "$mode" == qa-clock-epoch || "$mode" == qa-app-frame ]]; then
  command+=(--dart-define=TJ45F_ANDROID_PRESENTATION=true)
fi
if [[ "$mode" == qa-ui-build || "$mode" == qa-frame-scheduler || "$mode" == qa-wall-clock || "$mode" == qa-frame-request || "$mode" == qa-native-handoff || "$mode" == qa-clock-epoch || "$mode" == qa-app-frame ]]; then
  command+=(--dart-define=TJ45G_UI_BUILD=true)
fi
if [[ "$mode" == qa-frame-scheduler || "$mode" == qa-wall-clock || "$mode" == qa-frame-request || "$mode" == qa-native-handoff || "$mode" == qa-clock-epoch || "$mode" == qa-app-frame ]]; then
  command+=(--dart-define=TJ45H_FRAME_SCHEDULER=true)
fi
if [[ "$mode" == qa-wall-clock || "$mode" == qa-frame-request || "$mode" == qa-native-handoff || "$mode" == qa-clock-epoch || "$mode" == qa-app-frame ]]; then
  command+=(--dart-define=TJ45I_WALL_CLOCK_CORRELATION=true)
fi
if [[ "$mode" == qa-frame-request || "$mode" == qa-native-handoff || "$mode" == qa-clock-epoch || "$mode" == qa-app-frame ]]; then
  command+=(--dart-define=TJ45K_FRAME_REQUEST=true)
fi
if [[ "$mode" == qa-native-handoff || "$mode" == qa-clock-epoch || "$mode" == qa-app-frame ]]; then
  command+=(--dart-define=TJ45L_NATIVE_HANDOFF=true)
fi
if [[ "$mode" == qa-clock-epoch || "$mode" == qa-app-frame ]]; then
  command+=(--dart-define=TJ45M_CLOCK_EPOCH=true)
fi
if [[ "$mode" == qa-app-frame ]]; then
  command+=(--dart-define=TJ45N_APP_FRAME_TRACE=true)
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
      'timeout|timed out|Gateway Time-out|HTTP (429|502|503|504)|Received status code (429|502|503|504)|HTTP response code: (429|502|503|504)|SocketTimeoutException|Connection reset|Could not GET|Network is unreachable|Temporary failure in name resolution|Downloading from .* failed' \
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
