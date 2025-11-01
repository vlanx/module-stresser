#!/usr/bin/env bash
# Minimal fio launcher — zero safety checks, zero telemetry.
# Reads env, substitutes into a mode-matched template, runs fio, exits with fio's status.

# Where templates live (mount or copy into the container as you like)
TEMPLATE_DIR="${TEMPLATE_DIR:-./templates}"
JOB_TMP="${JOB_TMP:-/tmp/fio.job}"

# Mode selects the template filename: seq-read | seq-write | randread | randwrite
MODE="${MODE:-}"

# Core knobs (defaults align with the ultralight spec)
FILE_SIZE_GB="${FILE_SIZE_GB:-8}"
RUNTIME_SEC="${RUNTIME_SEC:-600}"
NUMJOBS="${NUMJOBS:-1}"
TEST_DIR="${TEST_DIR:-test_dir/}"
FILENAME="${FILENAME:-fio_rand.dat}"
# Select a pattern to write. This helps debugging we actually wrote to the file.
# You can check which `xxd -l 64 -s 0 "$FILE"`
PATTERN="${PATTERN:-0x99}"

# Mode-dependent defaults (no validation, just fill if unset)
case "$MODE" in
seq-read | seq-write)
	: "${BLOCK_SIZE:=1M}"
	: "${IODEPTH:=1}"
	;;
rand-read | rand-write)
	: "${BLOCK_SIZE:=4K}"
	: "${IODEPTH:=4}"
	;;
*) : ;; # If MODE is wrong, that's on the caller; we don't guard it.
esac

# Export for envsubst
export TEST_DIR FILE_SIZE_GB RUNTIME_SEC BLOCK_SIZE IODEPTH NUMJOBS FILENAME PATTERN

# Materialize job from template (requires 'envsubst' in the image)
tmpl="${TEMPLATE_DIR}/${MODE}.fio"
envsubst <"$tmpl" >"$JOB_TMP"

# Optional CLI overrides (kept out of templates on purpose)
args=()
[ -n "${ENGINE:-}" ] && args+=("--ioengine=${ENGINE}")
[ -n "${RNG_SEED:-}" ] && args+=("--randseed=${RNG_SEED}")

case "$MODE" in
seq-*) [ -n "${TARGET_MBPS:-}" ] && args+=("--rate=${TARGET_MBPS}m") ;;
rand*) [ -n "${TARGET_IOPS:-}" ] && args+=("--rate_iops=${TARGET_IOPS}") ;;
esac

# Run fio; pass through raw output; bubble up its exit code
fio "${args[@]}" "$JOB_TMP"
rc=$?

exit $rc
