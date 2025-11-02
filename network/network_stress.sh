#!/usr/bin/env bash
# Network Stress — iperf3 (client)
# Runs a single iperf3 test with clean env-driven knobs.
set -euo pipefail

# ---------- tunables (env vars) ----------
: "${SERVER:?Set SERVER to the iperf3 server hostname/IP}"
: "${PORT:=5201}"        # server port
: "${PROTO:=tcp}"        # tcp | udp
: "${DIRECTION:=upload}" # upload | download   (download => reverse)
: "${TIME:=20}"          # test duration (seconds)
: "${BANDWIDTH:=100}"    # target rate, e.g. 100M (--bandwidth). For UDP it's the send rate.
: "${BIND:=}"            # bind local IP (-B)
: "${PARALLEL:=1}"       # parallel client streams (-P)
: "${INTERVAL:=0}"       # seconds between reports (-i)
: "${WINDOW:=}"          # TCP window size, e.g. 512K (-w) [TCP only]
: "${LENGTH:=}"          # block/packet length, e.g. 1460 (-l)
: "${ZEROCOPY:=1}"       # 1 => TCP zero-copy (-Z)
: "${TCP_NODELAY:=0}"    # 1 => disable Nagle (-N)
: "${BIDIR:=0}"          # 1 => bidirectional test (--bidir)
: "${EXTRA_ARGS:=}"      # raw extra args (single string)

case "${PROTO}" in
tcp | udp) ;;
*)
	echo "error: PROTO must be 'tcp' or 'udp' (got: ${PROTO})" >&2
	exit 64
	;;
esac

case "${DIRECTION}" in
upload | download) ;;
*)
	echo "error: DIRECTION must be 'upload' or 'download' (got: ${DIRECTION})" >&2
	exit 64
	;;
esac

# ---------- build command ----------
cmd=(/usr/bin/iperf3 -c "${SERVER}" -p "${PORT}" -b "${BANDWIDTH}"M -t "${TIME}" -P "${PARALLEL}" -i "${INTERVAL}")

[[ "${PROTO}" == "udp" ]] && cmd+=(-u)
[[ "${DIRECTION}" == "download" ]] && cmd+=(-R)

[[ -n "${WINDOW}" && "${PROTO}" == "tcp" ]] && cmd+=(-w "${WINDOW}")
[[ -n "${LENGTH}" ]] && cmd+=(-l "${LENGTH}")
[[ -n "${BIND}" ]] && cmd+=(-B "${BIND}")

[[ "${ZEROCOPY}" -eq 1 ]] && cmd+=(-Z)
[[ "${TCP_NODELAY}" -eq 1 ]] && cmd+=(-N)
[[ "${BIDIR}" -eq 1 ]] && cmd+=(--bidir)

if [[ -n "${EXTRA_ARGS}" ]]; then
	# shellcheck disable=SC2206
	extra=(${EXTRA_ARGS})
	cmd+=("${extra[@]}")
fi

echo "[module_stresser - network] server=${SERVER}:${PORT} PROTO=${PROTO} DIR=${DIRECTION} time=${TIME}s P=${PARALLEL} bandwidth=${BANDWIDTH:-<auto>}M win=${WINDOW:-<auto>} len=${LENGTH:-<auto>}"

# ---------- run ----------
exec "${cmd[@]}"
