#!/usr/bin/env bash
set -euo pipefail

# Tunables (env vars)
: "${WORKERS:=$(nproc)}"     # how many CPU workers to spawn
: "${LOAD:=100}"             # per-worker load percentage (0..100)
: "${TIMEOUT:=5m}"           # run duration, e.g. 30s, 5m, 1h
: "${METHOD:=float64}"           # cpu method (e.g., all, matrixprod, fft, crc16, ackermann)
: "${CPUSET:=}"              # optional CPU list/mask for taskset, e.g., "0-3" or "0,2,4"
: "${METRICS_BRIEF:=1}"      # 1 => add --metrics-brief
: "${PERF:=0}"               # 1 => add --perf (needs kernel perf + permissions)
: "${EXTRA_ARGS:=}"          # any extra raw args to pass to stress-ng

cmd=(/usr/bin/stress-ng --cpu "${WORKERS}" --cpu-load "${LOAD}" \
     --cpu-method "${METHOD}" --timeout "${TIMEOUT}")

if [[ "${METRICS_BRIEF}" == "1" ]]; then
  cmd+=(--metrics-brief)
fi
if [[ "${PERF}" == "1" ]]; then
  cmd+=(--perf)
fi

if [[ -n "${CPUSET}" ]]; then
  echo "[module_stresser - cpu] cpu pinning: ${CPUSET}"
  cmd+=(--taskset "${CPUSET}")
fi

if [[ -n "${EXTRA_ARGS}" ]]; then
  # Allow users to inject additional flags as a single string
  # shellcheck disable=SC2206
  extra=(${EXTRA_ARGS})
  cmd+=("${extra[@]}")
fi

echo "[module_stresser - cpu] workers=${WORKERS} load=${LOAD}% method=${METHOD} timeout=${TIMEOUT} perf=${PERF} cpuset=${CPUSET:-<none>}"

exec "${cmd[@]}"
