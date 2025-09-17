#!/usr/bin/env bash
# Memory Stress — Container (Memrate)
# Drives sequential DRAM traffic at specified or uncapped MB/s (read/write).
set -Eeuo pipefail

# ---------- helpers ----------
die() {
	echo "error: $*" >&2
	exit 2
}

to_bytes_from_gb() {
	# prints integer bytes for a (possibly fractional) GB value
	echo "$(($1 * 1024 * 1024 * 1024))"
}

# ---------- env + defaults ----------
WORKERS="${WORKERS:-1}"
READ_MBPS="${READ_MBPS:-0}"   # integer MB/s, 0 disables reads or -1 for no cap
WRITE_MBPS="${WRITE_MBPS:-0}" # integer MB/s, 0 disables writes or -1 for no cap
TIMEOUT="${TIMEOUT:-60s}"
SIZE_GB="${SIZE_GB:-}" # REQUIRED
MEMRATE_FLUSH="${MEMRATE_FLUSH:-false}"
MEMRATE_METHOD="${MEMRATE_METHOD:-all}" # optional flag to specify read/write method
CPUSET="${CPUSET:-}"                    # optional CPU list, e.g. 0-7 or 0,2,4,6

# ---------- validate ----------
[[ "$WORKERS" =~ ^[1-9][0-9]*$ ]] || die "WORKERS must be a positive integer."
[[ -n "$SIZE_GB" ]] || die "SIZE_GB is required (total working set across all workers)."
[[ "$READ_MBPS" =~ ^(-1|\+?[0-9]+)$ ]] || die "READ_MBPS must be an integer ≥ -1."
[[ "$WRITE_MBPS" =~ ^(-1|\+?[0-9]+)$ ]] || die "WRITE_MBPS must be an integer ≥ -1."
[[ -n "$TIMEOUT" ]] || die "TIMEOUT must be non-empty (e.g., 60s, 5m)."

BYTES=$(to_bytes_from_gb "$SIZE_GB")

# ---------- log config ----------
echo "memrate: config {\"WORKERS\":$WORKERS,\"READ_MBPS\":$READ_MBPS,\"WRITE_MBPS\":$WRITE_MBPS,\"SIZE_GB\":$SIZE_GB,\"TIMEOUT\":\"$TIMEOUT\",\"MEMRATE_FLUSH\":\"$MEMRATE_FLUSH\",\"MEMRATE_METHOD\":\"$MEMRATE_METHOD\",\"CPUSET\":\"$CPUSET\"}"

# ---------- build command ----------
cmd=(stress-ng
	--memrate "$WORKERS"
	--memrate-bytes "$BYTES"
	--memrate-method "$MEMRATE_METHOD"
	--timeout "$TIMEOUT"
)

# Apply read/write rate caps unless both are -1
if [[ "$READ_MBPS" -eq -1 && "$WRITE_MBPS" -eq -1 ]]; then
	echo "memrate: no read or write MB/s caps"
elif [[ "$READ_MBPS" -eq -1 ]]; then
	echo "memrate: no read MB/s cap"
	echo "memrate: write MB/s cap is $WRITE_MBPS"
	cmd+=(--memrate-wr-mbs "$WRITE_MBPS")
elif [[ "$WRITE_MBPS" -eq -1 ]]; then
	echo "memrate: no write MB/s cap"
	echo "memrate: read MB/s cap is $READ_MBPS"
	cmd+=(--memrate-rd-mbs "$READ_MBPS")
else
	echo "memrate: read MB/s cap is $READ_MBPS"
	echo "memrate: write MB/s cap is $WRITE_MBPS"
	cmd+=(--memrate-rd-mbs "$READ_MBPS" --memrate-wr-mbs "$WRITE_MBPS")
fi

# Option to "flush cache between each memory test to remove caching benefits in memory rate metrics." as per documentation.
if [[ "$MEMRATE_FLUSH" = "true" ]]; then
	cmd+=(--memrate-flush)
fi

# Pin to specific CPUs
if [[ -n "${CPUSET}" ]]; then
	echo "[module_stresser - cpu] cpu pinning: ${CPUSET}"
	cmd+=(--taskset "${CPUSET}")
fi

# ---------- run ----------
exec "${cmd[@]}"
