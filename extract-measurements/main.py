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
        by = pivot_cfg["by"]
        q.append(
            f'|> pivot(rowKey:["_time"], columnKey: ["{by}"], valueColumn: "_value")'
        )
    return "\n".join(q)


def safe_dirname(s: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", s).strip("_")


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
    token = os.getenv("INFLUX_TOKEN")
    if not token:
        print(f"Missing token env var: $INFLUX_TOKEN={token}")
        return 2

    padding = int((cfg.get("defaults") or {}).get("padding_seconds", 60))

    runs: List[RunWindow] = []
    with open(log_path, "r", encoding="utf-8") as f:
        for line in f:
            r = parse_log_line(line.strip())
            if r:
                runs.append(r)

    if not runs:
        print("No runs found in log.")
        return 1

    # bump timeout if needed (ms)
    client = InfluxDBClient(url=influx["url"], token=token, org=org, timeout=180_000)

    with client:
        for r in runs:
            q_start = r.started - timedelta(seconds=padding)
            q_stop = r.finished + timedelta(seconds=padding)

            run_dir = os.path.join(out_dir, safe_dirname(f"{r.module}_{r.pct}"))
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
                flux = build_flux_query(bucket, sensor, q_start, q_stop)
                df = client.query_api().query_data_frame(query=flux, org=org)

                if df is None or (isinstance(df, list) and len(df) == 0):
                    continue
                if isinstance(df, list):
                    df = pd.concat(df, ignore_index=True)

                for col in ["result", "table"]:
                    if col in df.columns:
                        df = df.drop(columns=[col])

                if df.empty:
                    continue

                df["_time"] = pd.to_datetime(df["_time"], utc=True)
                df = df.sort_values("_time")

                out_path = os.path.join(run_dir, f"{sensor['name']}.csv")
                df.to_csv(out_path, index=False)
                print(f"[ok] {out_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
