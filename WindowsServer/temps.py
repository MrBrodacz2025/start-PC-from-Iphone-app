"""Odczyt temperatur podzespołów Windows (ACPI / LibreHardwareMonitor / NVIDIA)."""

from __future__ import annotations

import json
import re
import subprocess
from typing import Any


def _run_powershell(script: str) -> Any:
    completed = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy", "Bypass",
            "-Command", script,
        ],
        capture_output=True,
        text=True,
        timeout=8,
        encoding="utf-8",
        errors="ignore",
    )
    raw = (completed.stdout or "").strip()
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


def _normalize_list(data: Any) -> list[dict]:
    if data is None:
        return []
    if isinstance(data, dict):
        return [data]
    if isinstance(data, list):
        return [item for item in data if isinstance(item, dict)]
    return []


def _from_acpi() -> list[dict]:
    script = r"""
$items = Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue |
  ForEach-Object {
    [PSCustomObject]@{
      name = if ($_.InstanceName) { $_.InstanceName } else { 'Strefa termiczna' }
      celsius = [math]::Round(($_.CurrentTemperature / 10.0) - 273.15, 1)
      kind = 'acpi'
    }
  }
if ($items) { $items | ConvertTo-Json -Compress -Depth 3 }
"""
    return _normalize_list(_run_powershell(script))


def _from_libre_hardware_monitor() -> list[dict]:
    script = r"""
$items = Get-CimInstance -Namespace root/LibreHardwareMonitor -ClassName Sensor -ErrorAction SilentlyContinue |
  Where-Object { $_.SensorType -eq 'Temperature' -and $null -ne $_.Value } |
  ForEach-Object {
    [PSCustomObject]@{
      name = $_.Name
      celsius = [math]::Round([double]$_.Value, 1)
      kind = 'hardware'
      parent = $_.Parent
    }
  }
if ($items) { $items | ConvertTo-Json -Compress -Depth 3 }
"""
    return _normalize_list(_run_powershell(script))


def _from_nvidia() -> list[dict]:
    try:
        completed = subprocess.run(
            [
                "nvidia-smi",
                "--query-gpu=name,temperature.gpu",
                "--format=csv,noheader,nounits",
            ],
            capture_output=True,
            text=True,
            timeout=5,
            encoding="utf-8",
            errors="ignore",
        )
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return []

    sensors: list[dict] = []
    for line in (completed.stdout or "").splitlines():
        parts = [p.strip() for p in line.split(",")]
        if len(parts) < 2:
            continue
        try:
            temp = float(parts[1])
        except ValueError:
            continue
        sensors.append({
            "name": f"GPU {parts[0]}",
            "celsius": round(temp, 1),
            "kind": "gpu",
        })
    return sensors


def _friendly_name(raw: str, kind: str, index: int) -> str:
    lower = raw.lower()
    if kind == "gpu" or "gpu" in lower:
        return raw if raw.startswith("GPU") else f"GPU · {raw}"
    if "cpu" in lower or "package" in lower or "core" in lower:
        return f"CPU · {raw}"
    if "ssd" in lower or "nvme" in lower or "hdd" in lower or "drive" in lower:
        return f"Dysk · {raw}"
    if "motherboard" in lower or "mainboard" in lower or "pch" in lower or "system" in lower:
        return f"Płyta · {raw}"
    if kind == "acpi":
        return f"Strefa termiczna {index}"
    return raw


def collect_temperatures() -> dict:
    raw: list[dict] = []
    raw.extend(_from_libre_hardware_monitor())
    raw.extend(_from_nvidia())
    if not raw:
        raw.extend(_from_acpi())

    seen: set[str] = set()
    sensors: list[dict] = []
    for idx, item in enumerate(raw, start=1):
        try:
            celsius = float(item.get("celsius"))
        except (TypeError, ValueError):
            continue
        if celsius < 0 or celsius > 125:
            continue
        name = str(item.get("name") or f"Sensor {idx}")
        kind = str(item.get("kind") or "unknown")
        key = re.sub(r"\s+", " ", f"{kind}:{name}").strip().lower()
        if key in seen:
            continue
        seen.add(key)
        sensors.append({
            "id": f"{kind}-{idx}",
            "name": _friendly_name(name, kind, idx),
            "celsius": round(celsius, 1),
            "kind": kind,
        })

    sensors.sort(key=lambda s: s["celsius"], reverse=True)
    return {
        "sensors": sensors,
        "count": len(sensors),
        "source": "libre+nvidia" if any(s["kind"] in ("hardware", "gpu") for s in sensors) else "acpi",
    }
