#!/usr/bin/env bash

set -euo pipefail

# =========================================================
# InfluxDB configuration
# =========================================================

INFLUX_HOST="http://10.255.35.63:8086"

INFLUX_TOKEN="PmHsyFvIxxf0ubR7Cya7FUFVwgo2DoOQHZkgrj8NwCvc7OQrFRnGKxNjmcWwbvOVqT2Q380m57_XqkWcLZNxTA=="

INFLUX_ORG="it"

INFLUX_BUCKET="energy"

OUTPUT_DIR="./energy_csv_exports"

# =========================================================
# Measurements
# =========================================================

MEASUREMENTS=(
  "alumet"
  "clamp-shelly"
  "ipmi_snmp"
  "kepler"
  "pdu125"
  "pdu143"
  "pdu144"
  "scaphandre"
  "shelly_pdu_143"
  "shelly_pdu_144"
)

# =========================================================
# Host time windows
# =========================================================

HOSTS=(
  "ultrap3"
  "laptophp"
  "test5"
)

HOST_STARTS=(
  "2026-03-02T17:00:00Z"
  "2026-03-03T22:30:00Z"
  "2026-03-04T16:00:00Z"
)

HOST_STOPS=(
  "2026-03-03T00:00:00Z"
  "2026-03-04T05:30:00Z"
  "2026-03-04T23:00:00Z"
)

SERVER_TAGS=(
  "ultraP3"
  "laptopHP"
  "atnog-test5"
)

# =========================================================
# Dependency checks
# =========================================================

if ! command -v curl >/dev/null 2>&1; then
    echo "Error: required command not found: curl" >&2
    exit 127
fi

field_filter_for_measurement() {
    case "$1" in
        kepler)
            echo '  |> filter(fn: (r) => r._field =~ /^kepler_node_/)'
            ;;
        scaphandre)
            echo '  |> filter(fn: (r) => r._field !~ /process/)'
            ;;
        clamp-shelly)
            echo '  |> filter(fn: (r) => r._field =~ /_power$/)'
            ;;
        shelly_pdu_143|shelly_pdu_144)
            echo '  |> filter(fn: (r) => r._field == "apower")'
            ;;
        ipmi_snmp)
            echo '  |> filter(fn: (r) => r._field =~ /^psu/)'
            ;;
    esac
}

# =========================================================
# Create output directory
# =========================================================

mkdir -p "${OUTPUT_DIR}"

# =========================================================
# Export loop
# =========================================================

for HOST_INDEX in "${!HOSTS[@]}"; do

    HOST="${HOSTS[$HOST_INDEX]}"

    HOST_DIR="${OUTPUT_DIR}/${HOST}"

    mkdir -p "${HOST_DIR}"

    START_TIME="${HOST_STARTS[$HOST_INDEX]}"
    STOP_TIME="${HOST_STOPS[$HOST_INDEX]}"
    SERVER_TAG="${SERVER_TAGS[$HOST_INDEX]}"

    echo ""
    echo "================================================="
    echo "Exporting host: ${HOST}"
    echo "SERVER: ${SERVER_TAG}"
    echo "START: ${START_TIME}"
    echo "STOP : ${STOP_TIME}"
    echo "================================================="

    for MEASUREMENT in "${MEASUREMENTS[@]}"; do

        OUTPUT_FILE="${HOST_DIR}/${HOST}_${MEASUREMENT}.csv"

        echo ""
        echo "Measurement: ${MEASUREMENT}"
        echo "Output: ${OUTPUT_FILE}"

        FIELD_FILTER="$(field_filter_for_measurement "${MEASUREMENT}")"

        curl \
          --fail \
          --silent \
          --show-error \
          --location \
          --request POST \
          "${INFLUX_HOST}/api/v2/query?org=${INFLUX_ORG}" \
          --header "Authorization: Token ${INFLUX_TOKEN}" \
          --header "Accept: application/csv" \
          --header "Content-Type: application/vnd.flux" \
          --data-binary "
from(bucket: \"${INFLUX_BUCKET}\")
  |> range(start: ${START_TIME}, stop: ${STOP_TIME})
  |> filter(fn: (r) => r._measurement == \"${MEASUREMENT}\")
  |> filter(fn: (r) => r.server == \"${SERVER_TAG}\")
${FIELD_FILTER}
  |> sort(columns: [\"_time\"])
" > "${OUTPUT_FILE}"

    done

done

echo ""
echo "================================================="
echo "CSV export completed successfully"
echo "Directory: ${OUTPUT_DIR}"
echo "================================================="
