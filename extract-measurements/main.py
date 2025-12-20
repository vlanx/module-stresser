#!/usr/bin/env python3
from __future__ import annotations

import os, re, sys, json, yaml
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

import pandas as pd
from influxdb_client.client.influxdb_client import InfluxDBClient

import warnings
from influxdb_client.client.warnings import MissingPivotFunction

warnings.simplefilter("ignore", MissingPivotFunction)


LOG_RE = re.compile(
    r'name="(?P<name>[^"]+)"\s+started=(?P<started>\S+)\s+&\s+finished=(?P<finished>\S+)'
)


def parse_rfc3339(ts: str) -> datetime:
    if ts.endswith("Z"):
        ts = ts[:-1] + "+00:00"
    return datetime.fromisoformat(ts).astimezone(timezone.utc)


@dataclass
class RunWindow:
    test_name: str
    module: str
    pct: str
    started: datetime
    finished: datetime


def parse_log_line(line: str) -> Optional[RunWindow]:
    m = LOG_RE.search(line)
    if not m:
        return None
    name = m.group("name")
    started = parse_rfc3339(m.group("started"))
    finished = parse_rfc3339(m.group("finished"))
    parts = name.split("-")
    module = parts[0] if len(parts) > 0 else "unknown"
    pct = parts[2] if len(parts) > 2 else "unknown"
    return RunWindow(name, module, pct, started, finished)


def flux_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def build_flux_query(
    bucket: str,
    sensor: Dict[str, Any],
    start: datetime,
    stop: datetime,
) -> str:
    measurement = sensor["measurement"]
    fields = sensor.get("fields") or []
    tag_in = sensor.get("tag_in") or {}
    keep_tags = sensor.get("keep_tags") or []

    start_s = start.isoformat().replace("+00:00", "Z")
    stop_s = stop.isoformat().replace("+00:00", "Z")

    q: List[str] = []
    q.append(f'from(bucket: "{flux_escape(bucket)}")')
    q.append(f'  |> range(start: time(v: "{start_s}"), stop: time(v: "{stop_s}"))')
    q.append(
        f'  |> filter(fn: (r) => r["_measurement"]  == "{flux_escape(measurement)}")'
    )

    # tag IN filters (expanded ORs for performance)
    for k, values in tag_in.items():
        key = flux_escape(k)
        ors = " or ".join(f'r["{key}"] == "{flux_escape(v)}"' for v in values)
        q.append(f"  |> filter(fn: (r) => {ors})")

    # field filter
    if fields:
        if len(fields) == 1:
            f = flux_escape(fields[0])
            q.append(f'  |> filter(fn: (r) => r._field == "{f}")')
        else:
            set_list = ", ".join([f'"{flux_escape(f)}"' for f in fields])
            q.append(
                f"  |> filter(fn: (r) => contains(value: r._field, set: [{set_list}]))"
            )

    keep_cols = (
        ["_time", "_measurement", "_field", "_value"] + keep_tags + list(tag_in.keys())
    )
    keep_cols = sorted(set(keep_cols))
    keep_list = ", ".join([f'"{flux_escape(c)}"' for c in keep_cols])

    q.append(f"  |> keep(columns: [{keep_list}])")

    # pivot for alumet
    pivot_cfg = sensor.get("pivot")
    if pivot_cfg:
        by = flux_escape(str(pivot_cfg["by"]))
        q.append(
            f'  |> pivot(rowKey:["_time"], columnKey: ["{by}"], valueColumn: "_value")'
        )
    return "\n".join(q)


def safe_dirname(s: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", s).strip("_")


def export_sensor_csv(
    client: InfluxDBClient,
    org: str,
    bucket: str,
    sensor: Dict[str, Any],
    start: datetime,
    stop: datetime,
    out_path: str,
) -> bool:
    """Query Influx once for a sensor and write a single CSV.

    Returns True if a non-empty CSV was written.
    """

    flux = build_flux_query(bucket, sensor, start, stop)
    print(f"Query: {flux}")
    df = client.query_api().query_data_frame(query=flux, org=org)

    if df is None or (isinstance(df, list) and len(df) == 0):
        return False
    if isinstance(df, list):
        df = pd.concat(df, ignore_index=True)

    for col in ["result", "table"]:
        if col in df.columns:
            df = df.drop(columns=[col])

    if df.empty:
        return False

    if "_time" in df.columns:
        df["_time"] = pd.to_datetime(df["_time"], utc=True)
        df = df.sort_values("_time")

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    df.to_csv(out_path, index=False)
    return True


def main() -> int:
    if len(sys.argv) < 4:
        print("Usage: export_runs_raw.py <config.yaml> <runs.log> <output_dir>")
        return 2

    cfg_path, log_path, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
    os.makedirs(out_dir, exist_ok=True)

    with open(cfg_path, "r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f)

    influx = cfg["influx"]
    bucket = influx["bucket"]
    org = influx["org"]
    token_env = influx.get("token_env") or "INFLUX_TOKEN"
    token = os.getenv(token_env)
    if not token:
        print(f"Missing token env var: ${token_env}")
        return 2

    defaults = cfg.get("defaults") or {}
    padding = int(defaults.get("padding_seconds", 60))
    # Whole-run padding (falls back to per-test padding if not provided)
    master_padding = int(defaults.get("master_padding_seconds", padding))

    runs: List[RunWindow] = []
    with open(log_path, "r", encoding="utf-8") as f:
        for line in f:
            r = parse_log_line(line.strip())
            if r:
                runs.append(r)

    if not runs:
        print("No runs found in log.")
        return 1

    # Whole-run (master) window: first test start -> last test finish
    master_start = min(r.started for r in runs) - timedelta(seconds=master_padding)
    master_stop = max(r.finished for r in runs) + timedelta(seconds=master_padding)

    # bump timeout if needed (ms)
    client = InfluxDBClient(url=influx["url"], token=token, org=org, timeout=180_000)

    with client:
        # Per-test exports (existing behavior)
        for r in runs:
            q_start = r.started - timedelta(seconds=padding)
            q_stop = r.finished + timedelta(seconds=padding)

            run_dir = os.path.join(out_dir, safe_dirname(f"{r.test_name}"))
            os.makedirs(run_dir, exist_ok=True)

            meta = {
                "module": r.module,
                "pct": r.pct,
                "started": r.started.isoformat().replace("+00:00", "Z"),
                "finished": r.finished.isoformat().replace("+00:00", "Z"),
                "query_start": q_start.isoformat().replace("+00:00", "Z"),
                "query_stop": q_stop.isoformat().replace("+00:00", "Z"),
                "padding_seconds": padding,
            }
            with open(os.path.join(run_dir, "meta.json"), "w", encoding="utf-8") as mf:
                json.dump(meta, mf, indent=2)

            for sensor in cfg.get("sensors", []):
                out_path = os.path.join(run_dir, f"{sensor['name']}.csv")
                if export_sensor_csv(
                    client, org, bucket, sensor, q_start, q_stop, out_path
                ):
                    print(f"[ok] {out_path}")

        # Whole-run exports: one CSV per sensor spanning the entire workflow
        master_dir = os.path.join(out_dir, "full-test")
        os.makedirs(master_dir, exist_ok=True)
        for sensor in cfg.get("sensors", []):
            out_path = os.path.join(master_dir, f"{sensor['name']}.csv")
            if export_sensor_csv(
                client, org, bucket, sensor, master_start, master_stop, out_path
            ):
                print(f"[master] {out_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
