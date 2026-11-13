"""Temperatury + metryki PC (LibreHardwareMonitor DLL, NVIDIA, psutil)."""

from __future__ import annotations

import json
import re
import subprocess
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

try:
    import psutil
except ImportError:  # pragma: no cover
    psutil = None

ROOT = Path(__file__).resolve().parent
LHM_DIR = ROOT / "tools" / "LibreHardwareMonitor"
LHM_EXE = LHM_DIR / "LibreHardwareMonitor.exe"
LHM_PS1 = ROOT / "read_lhm.ps1"
LHM_URL = "http://127.0.0.1:8085/data.json"

_cache_lock = threading.Lock()
_cache_payload: dict[str, Any] | None = None
_cache_at = 0.0
_CACHE_TTL = 4.0
_lhm_warmed = False


def _run_powershell_file(path: Path, timeout: int = 20) -> Any:
    completed = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy", "Bypass",
            "-File", str(path),
        ],
        capture_output=True,
        text=True,
        timeout=timeout,
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


def ensure_libre_hardware_monitor() -> bool:
    global _lhm_warmed
    if not LHM_EXE.exists():
        return False
    if psutil is not None:
        for proc in psutil.process_iter(["name"]):
            try:
                if (proc.info.get("name") or "").lower() == "librehardwaremonitor.exe":
                    _lhm_warmed = True
                    return True
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
    try:
        subprocess.Popen(
            [str(LHM_EXE)],
            cwd=str(LHM_DIR),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        time.sleep(2)
        _lhm_warmed = True
        return True
    except OSError:
        return False


def _parse_celsius(value: str | None) -> float | None:
    if not value:
        return None
    match = re.search(r"(-?\d+(?:[.,]\d+)?)\s*°?\s*C", value, re.IGNORECASE)
    if not match:
        return None
    try:
        return float(match.group(1).replace(",", "."))
    except ValueError:
        return None


def _walk_lhm_nodes(node: dict, path: list[str], out: list[dict]) -> None:
    text = str(node.get("Text") or "")
    value = node.get("Value")
    celsius = _parse_celsius(str(value) if value is not None else None)
    if celsius is not None and 1 < celsius <= 120:
        joined = " / ".join([*path, text]) if path else text
        kind = "hardware"
        lower = joined.lower()
        if "gpu" in lower or "nvidia" in lower or "radeon" in lower:
            kind = "gpu"
        elif "cpu" in lower or "core" in lower or "package" in lower or "tctl" in lower or "tdie" in lower or "ryzen" in lower:
            kind = "cpu"
        elif "ssd" in lower or "nvme" in lower or "hdd" in lower or "drive" in lower or "storage" in lower:
            kind = "disk"
        elif "motherboard" in lower or "mainboard" in lower or "pch" in lower:
            kind = "board"
        out.append({
            "name": text,
            "celsius": round(celsius, 1),
            "kind": kind,
            "path": joined,
            "hardware": path[0] if path else text,
        })
    children = node.get("Children") or []
    if isinstance(children, list):
        next_path = [*path, text] if text else path
        for child in children:
            if isinstance(child, dict):
                _walk_lhm_nodes(child, next_path, out)


def _from_lhm_http() -> list[dict]:
    try:
        with urllib.request.urlopen(LHM_URL, timeout=2) as response:
            payload = json.loads(response.read().decode("utf-8", errors="ignore"))
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError):
        return []
    found: list[dict] = []
    if isinstance(payload, dict):
        _walk_lhm_nodes(payload, [], found)
    return found


def _from_lhm_dll() -> list[dict]:
    if not LHM_PS1.exists() or not (LHM_DIR / "LibreHardwareMonitorLib.dll").exists():
        return []
    data = _run_powershell_file(LHM_PS1, timeout=25)
    items = _normalize_list(data)
    out: list[dict] = []
    for item in items:
        try:
            celsius = float(item.get("celsius"))
        except (TypeError, ValueError):
            continue
        if celsius <= 1 or celsius > 120:
            continue
        name = str(item.get("name") or "Sensor")
        hardware = str(item.get("hardware") or "")
        blob = f"{hardware} {name}".lower()
        kind = "hardware"
        if "gpu" in blob or "nvidia" in blob or "radeon" in blob:
            kind = "gpu"
        elif "ryzen" in blob or "intel" in blob or "cpu" in blob or "core" in blob or "tctl" in blob or "package" in blob:
            kind = "cpu"
        elif "ssd" in blob or "nvme" in blob or "hdd" in blob:
            kind = "disk"
        elif "motherboard" in blob or "asus" in blob or "msi" in blob or "gigabyte" in blob:
            kind = "board"
        out.append({
            "name": name,
            "celsius": round(celsius, 1),
            "kind": kind,
            "hardware": hardware,
            "path": f"{hardware} / {name}",
        })
    return out


def _from_nvidia() -> tuple[list[dict], dict]:
    gpu_metrics: dict[str, Any] = {}
    try:
        completed = subprocess.run(
            [
                "nvidia-smi",
                "--query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total",
                "--format=csv,noheader,nounits",
            ],
            capture_output=True,
            text=True,
            timeout=5,
            encoding="utf-8",
            errors="ignore",
        )
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return [], gpu_metrics

    sensors: list[dict] = []
    for line in (completed.stdout or "").splitlines():
        parts = [p.strip() for p in line.split(",")]
        if len(parts) < 2:
            continue
        try:
            temp = float(parts[1])
        except ValueError:
            continue
        name = parts[0]
        sensors.append({
            "name": f"GPU Core",
            "celsius": round(temp, 1),
            "kind": "gpu",
            "hardware": name,
            "path": f"{name} / GPU Core",
        })
        try:
            util = float(parts[2]) if len(parts) > 2 else None
            mem_used = float(parts[3]) if len(parts) > 3 else None
            mem_total = float(parts[4]) if len(parts) > 4 else None
        except ValueError:
            util = mem_used = mem_total = None
        gpu_metrics = {
            "name": name,
            "temperature_c": round(temp, 1),
            "utilization_percent": util,
            "memory_used_mb": mem_used,
            "memory_total_mb": mem_total,
        }
        break
    return sensors, gpu_metrics


def _friendly_name(raw: str, kind: str, index: int, hardware: str | None = None) -> str:
    if kind == "gpu":
        return f"GPU · {raw}"
    if kind == "cpu":
        suffix = f" ({hardware})" if hardware and "ryzen" in hardware.lower() else ""
        return f"CPU · {raw}{suffix}"
    if kind == "disk":
        return f"Dysk · {raw}"
    if kind == "board":
        return f"Płyta · {raw}"
    if hardware:
        return f"{hardware} · {raw}"
    return raw or f"Sensor {index}"


def collect_system_metrics() -> dict:
    metrics: dict[str, Any] = {
        "cpu_percent": None,
        "cpu_freq_mhz": None,
        "ram_percent": None,
        "ram_used_gb": None,
        "ram_total_gb": None,
        "disk_percent": None,
        "disk_used_gb": None,
        "disk_total_gb": None,
        "uptime_seconds": None,
        "gpu": None,
    }
    if psutil is None:
        return metrics

    metrics["cpu_percent"] = round(psutil.cpu_percent(interval=0.15), 1)
    freq = psutil.cpu_freq()
    if freq:
        metrics["cpu_freq_mhz"] = round(freq.current, 0)

    mem = psutil.virtual_memory()
    metrics["ram_percent"] = round(mem.percent, 1)
    metrics["ram_used_gb"] = round(mem.used / (1024 ** 3), 1)
    metrics["ram_total_gb"] = round(mem.total / (1024 ** 3), 1)

    try:
        disk = psutil.disk_usage("C:\\")
        metrics["disk_percent"] = round(disk.percent, 1)
        metrics["disk_used_gb"] = round(disk.used / (1024 ** 3), 1)
        metrics["disk_total_gb"] = round(disk.total / (1024 ** 3), 1)
    except OSError:
        pass

    metrics["uptime_seconds"] = int(time.time() - psutil.boot_time())
    return metrics


def _collect_raw() -> dict:
    ensure_libre_hardware_monitor()
    raw: list[dict] = []
    raw.extend(_from_lhm_http())
    if not any(s.get("kind") == "cpu" for s in raw):
        raw.extend(_from_lhm_dll())

    nvidia_sensors, gpu_metrics = _from_nvidia()
    if not any(s.get("kind") == "gpu" for s in raw):
        raw.extend(nvidia_sensors)

    seen: set[str] = set()
    sensors: list[dict] = []
    for idx, item in enumerate(raw, start=1):
        try:
            celsius = float(item.get("celsius"))
        except (TypeError, ValueError):
            continue
        if celsius <= 1 or celsius > 120:
            continue
        name = str(item.get("name") or f"Sensor {idx}")
        kind = str(item.get("kind") or "unknown")
        hardware = item.get("hardware")
        path = item.get("path")
        key = re.sub(r"\s+", " ", f"{kind}:{name}:{path or ''}").strip().lower()
        if key in seen:
            continue
        seen.add(key)
        sensors.append({
            "id": f"{kind}-{idx}",
            "name": _friendly_name(name, kind, idx, hardware if isinstance(hardware, str) else None),
            "celsius": round(celsius, 1),
            "kind": kind,
        })

    sensors.sort(key=lambda s: (0 if s["kind"] == "cpu" else 1 if s["kind"] == "gpu" else 2, -s["celsius"]))

    metrics = collect_system_metrics()
    if gpu_metrics:
        metrics["gpu"] = gpu_metrics

    return {
        "sensors": sensors,
        "count": len(sensors),
        "metrics": metrics,
        "source": "lhm+nvidia+psutil",
        "hint": None if any(s["kind"] == "cpu" for s in sensors) else (
            "Brak temperatury CPU: uruchom LibreHardwareMonitor jako Administrator "
            "(tools\\LibreHardwareMonitor) i w Options > Remote Web Server kliknij Run."
        ),
    }


def collect_temperatures() -> dict:
    global _cache_payload, _cache_at
    now = time.time()
    with _cache_lock:
        if _cache_payload is not None and (now - _cache_at) < _CACHE_TTL:
            return dict(_cache_payload)

    payload = _collect_raw()
    with _cache_lock:
        _cache_payload = payload
        _cache_at = time.time()
    return dict(payload)
