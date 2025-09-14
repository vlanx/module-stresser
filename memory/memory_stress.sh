#!/usr/bin/env bash
# Memory Stress — Container (Memrate)
# Drives sequential DRAM traffic at commanded absolute MB/s (read/write).
set -Eeuo pipefail

# ---------- helpers ----------
die() { echo "error: $*" >&2; exit 2; }

to_bytes_from_gb() {
  # prints integer bytes for a (possibly fractional) GB value
  # awk -v gb="$1" 'BEGIN{ printf "%.0f", gb * 1024 * 1024 * 1024 }'
  echo "$(($1 * 1024 * 1024 * 1024))"
}

# ---------- env + defaults ----------
READ_MBPS="${READ_MBPS:-0}"        # integer MB/s, 0 disables reads or -1 for no cap
WRITE_MBPS="${WRITE_MBPS:-0}"      # integer MB/s, 0 disables writes or -1 for no cap
THREADS="${THREADS:-4}"
DURATION="${DURATION:-60s}"
SIZE_GB="${SIZE_GB:-}"             # REQUIRED
MEMRATE_FLUSH="${MEMRATE_FLUSH:-false}"
MEMRATE_METHOD="${MEMRATE_METHOD:-all}"  # optional string
CPUSET="${CPUSET:-}"                  # optional CPU list, e.g. 0-7 or 0,2,4,6

# ---------- validate ----------
[[ -n "$SIZE_GB" ]] || die "SIZE_GB is required (total working set across all workers)."
[[ "$THREADS" =~ ^[1-9][0-9]*$ ]] || die "THREADS must be a positive integer."
[[ "$READ_MBPS" =~ ^[0-9]+$ ]] || die "READ_MBPS must be an integer ≥ 0."
[[ "$WRITE_MBPS" =~ ^[0-9]+$ ]] || die "WRITE_MBPS must be an integer ≥ 0."
[[ -n "$DURATION" ]] || die "DURATION must be non-empty (e.g., 60s, 5m)."

BYTES=$(to_bytes_from_gb "$SIZE_GB")

# ---------- log config ----------
echo "memrate: config {\"READ_MBPS\":$READ_MBPS,\"WRITE_MBPS\":$WRITE_MBPS,\"THREADS\":$THREADS,\"SIZE_GB\":$SIZE_GB,\"DURATION\":\"$DURATION\",\"MEMRATE_FLUSH\":\"$MEMRATE_FLUSH\",\"MEMRATE_METHOD\":\"$MEMRATE_METHOD\",\"CPUSET\":\"$CPUSET\"}"

# ---------- build command ----------
cmd=(stress-ng
  --memrate "$THREADS"
  --memrate-bytes "$BYTES"
  --memrate-method "$MEMRATE_METHOD"
  --timeout "$DURATION"
)

# Apply read/write rate caps unless both are -1 
if [[ "$READ_MBPS" -eq -1 && "$WRITE_MBPS" -eq -1 ]]; then
  echo "memrate: no rd/wr MB/s caps"
else
  cmd+=( --memrate-rd-mbs "$READ_MBPS" --memrate-wr-mbs "$WRITE_MBPS" )
fi

# Option to "flush cache between each memory test to remove caching benefits in memory rate metrics." as per documentation.
if [[ "$MEMRATE_FLUSH" = "true" ]]; then
    cmd+=( --memrate-flush )
fi

# Pin to specific CPUs
if [[ -n "${CPUSET}" ]]; then
    echo "[module_stresser - cpu] cpu pinning: ${CPUSET}"
    cmd+=(--taskset "${CPUSET}")
fi

# ---------- run ----------
exec "${cmd[@]}"
