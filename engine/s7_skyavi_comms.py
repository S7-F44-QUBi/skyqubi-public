# ═══════════════════════════════════════════════════════════════════
# S7 SkyQUBi™ — Covenant Witness System Engine
# Copyright 2024-2026 123Tech / 2XR, LLC. All rights reserved.
#
# Licensed under CWS-BSL-1.1 (see CWS-LICENSE at repo root)
# Patent Pending: TPP99606 — Jamie Lee Clayton / 123Tech / 2XR, LLC
#
# S7™, SkyQUBi™, SkyCAIR™, CWS™, ForToken™, RevToken™, ZeroClaw™,
# SkyAVi™, MemPalace™, and "Love is the architecture"™ are
# trademarks of 123Tech / 2XR, LLC.
#
# CIVILIAN USE ONLY — See CWS-LICENSE Civilian-Only Covenant.
# ═══════════════════════════════════════════════════════════════════
"""
S7 SkyAVi — Communications Intelligence
==========================================
Meshtastic mesh radio, GPS, space weather, propagation.
Works without hardware — degrades gracefully.

NOAA Space Weather: https://services.swpc.noaa.gov
Meshtastic: pip install meshtastic (optional)

Patent: TPP99606 — 123Tech / 2XR, LLC
"""

import os
import json
import time
import subprocess
from dataclasses import dataclass, field
from datetime import datetime, timezone

from s7_molecular import Bond

# NOAA Space Weather endpoints (public, no auth)
NOAA_KP_URL = "https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json"
NOAA_ALERTS_URL = "https://services.swpc.noaa.gov/products/alerts.json"
NOAA_SOLAR_WIND_URL = "https://services.swpc.noaa.gov/products/solar-wind/mag-1-day.json"

# Meshtastic defaults
MESH_DEVICE = os.getenv("S7_MESH_DEVICE", "/dev/ttyUSB0")


@dataclass
class MeshNode:
    node_id: str
    long_name: str = ""
    short_name: str = ""
    hw_model: str = ""
    latitude: float = 0.0
    longitude: float = 0.0
    altitude: float = 0.0
    battery: int = 0
    snr: float = 0.0
    last_heard: float = 0.0


@dataclass
class SpaceWeather:
    kp_index: float = 0.0
    kp_category: str = "QUIET"  # QUIET/UNSETTLED/ACTIVE/STORM/SEVERE
    solar_wind_speed: float = 0.0
    bt_nanoTesla: float = 0.0
    alerts: list[str] = field(default_factory=list)
    timestamp: str = ""
    rf_impact: str = "NONE"  # NONE/MINOR/MODERATE/SEVERE


def _curl_json(url: str, timeout: int = 10) -> dict | list | None:
    """Fetch JSON via curl (no Python HTTP dependency needed)."""
    try:
        result = subprocess.run(
            ["curl", "-s", "--max-time", str(timeout), url],
            capture_output=True, text=True, timeout=timeout + 5)
        if result.returncode == 0 and result.stdout.strip():
            return json.loads(result.stdout)
    except Exception:
        pass
    return None


def get_space_weather() -> SpaceWeather:
    """Fetch current space weather from NOAA."""
    sw = SpaceWeather(timestamp=datetime.now(timezone.utc).isoformat())

    # Kp index
    kp_data = _curl_json(NOAA_KP_URL)
    if kp_data and len(kp_data) > 0:
        try:
            latest = kp_data[-1]  # most recent entry
            if isinstance(latest, dict):
                sw.kp_index = float(latest.get("Kp", 0))
            elif isinstance(latest, list) and len(latest) > 1:
                sw.kp_index = float(latest[1])
        except (IndexError, ValueError, TypeError):
            pass

    # Categorize Kp
    if sw.kp_index >= 8:
        sw.kp_category = "SEVERE"
        sw.rf_impact = "SEVERE"
    elif sw.kp_index >= 6:
        sw.kp_category = "STORM"
        sw.rf_impact = "SEVERE"
    elif sw.kp_index >= 4:
        sw.kp_category = "ACTIVE"
        sw.rf_impact = "MODERATE"
    elif sw.kp_index >= 3:
        sw.kp_category = "UNSETTLED"
        sw.rf_impact = "MINOR"
    else:
        sw.kp_category = "QUIET"
        sw.rf_impact = "NONE"

    # Alerts
    alerts_data = _curl_json(NOAA_ALERTS_URL)
    if alerts_data and isinstance(alerts_data, list):
        for alert in alerts_data[:5]:
            msg = alert.get("message", "")[:200] if isinstance(alert, dict) else str(alert)[:200]
            if msg:
                sw.alerts.append(msg)

    return sw


def get_gps_satellites() -> dict:
    """Check GPS constellation status (from system if available)."""
    # Try gpsd first
    result = subprocess.run(
        ["gpspipe", "-w", "-n", "1"], capture_output=True, text=True, timeout=5
    ) if os.path.exists("/usr/bin/gpspipe") else None

    if result and result.returncode == 0:
        try:
            data = json.loads(result.stdout)
            return {"source": "gpsd", "data": data}
        except json.JSONDecodeError:
            pass

    return {"source": "unavailable", "data": {
        "note": "No GPS device. Install gpsd for live satellite tracking."
    }}


def get_mesh_status() -> dict:
    """Check Meshtastic device status."""
    try:
        import meshtastic
        import meshtastic.serial_interface
        iface = meshtastic.serial_interface.SerialInterface(MESH_DEVICE)
        nodes = []
        for node_id, node in iface.nodes.items():
            pos = node.get("position", {})
            metrics = node.get("deviceMetrics", {})
            nodes.append(MeshNode(
                node_id=node_id,
                long_name=node.get("user", {}).get("longName", ""),
                short_name=node.get("user", {}).get("shortName", ""),
                hw_model=node.get("user", {}).get("hwModel", ""),
                latitude=pos.get("latitude", 0),
                longitude=pos.get("longitude", 0),
                altitude=pos.get("altitude", 0),
                battery=metrics.get("batteryLevel", 0),
                snr=node.get("snr", 0),
                last_heard=node.get("lastHeard", 0),
            ))
        my_info = iface.getMyNodeInfo()
        iface.close()
        return {
            "connected": True,
            "device": MESH_DEVICE,
            "my_node": my_info.get("user", {}).get("longName", "unknown"),
            "nodes": len(nodes),
            "node_list": [{"id": n.node_id, "name": n.long_name,
                           "battery": n.battery, "snr": n.snr}
                          for n in nodes],
        }
    except ImportError:
        return {"connected": False, "error": "meshtastic package not installed. pip install meshtastic"}
    except Exception as e:
        return {"connected": False, "error": str(e)}


def send_mesh_message(text: str, dest: str = "^all") -> dict:
    """Send a message over Meshtastic mesh."""
    try:
        import meshtastic
        import meshtastic.serial_interface
        iface = meshtastic.serial_interface.SerialInterface(MESH_DEVICE)
        if dest == "^all":
            iface.sendText(text)
        else:
            iface.sendText(text, destinationId=dest)
        iface.close()
        return {"sent": True, "dest": dest, "text": text[:200]}
    except ImportError:
        return {"sent": False, "error": "meshtastic not installed"}
    except Exception as e:
        return {"sent": False, "error": str(e)}


def register_comms_skills(samuel):
    """Register communications skills on Samuel."""

    backend = samuel.backend

    @samuel.skill("space weather", category="comms", description="Check NOAA space weather and RF propagation")
    async def space_weather(self, message):
        sw = get_space_weather()
        lines = [
            f"Space Weather Report — {sw.timestamp[:19]}",
            f"  Kp Index:    {sw.kp_index} ({sw.kp_category})",
            f"  RF Impact:   {sw.rf_impact}",
        ]
        if sw.rf_impact != "NONE":
            lines.append(f"  WARNING: Kp {sw.kp_index} may degrade LoRa/HF/GPS")
        if sw.alerts:
            lines.append(f"  Alerts:      {len(sw.alerts)} active")
            for a in sw.alerts[:3]:
                lines.append(f"    - {a[:100]}")
        return "\n".join(lines)

    @samuel.skill("mesh status", category="comms", description="Check Meshtastic device and node list")
    async def mesh_status(self, message):
        status = get_mesh_status()
        if not status["connected"]:
            return f"Meshtastic: {status['error']}"
        lines = [
            f"Meshtastic — {status['my_node']}",
            f"  Device: {status['device']}",
            f"  Nodes:  {status['nodes']}",
        ]
        for n in status.get("node_list", [])[:10]:
            lines.append(f"    {n['name']:20s} bat={n['battery']}% snr={n['snr']}")
        return "\n".join(lines)

    @samuel.skill("mesh send", category="comms", description="Send a message over Meshtastic mesh")
    async def mesh_send(self, message):
        import re
        match = re.search(r'mesh send\s+(.+)', message, re.IGNORECASE)
        if not match:
            return "Usage: mesh send <message>"
        text = match.group(1).strip()
        result = send_mesh_message(text)
        if result["sent"]:
            return f"Sent to {result['dest']}: {result['text']}"
        return f"Send failed: {result['error']}"

    @samuel.skill("gps status", category="comms", description="Check GPS satellite constellation")
    async def gps_status(self, message):
        data = get_gps_satellites()
        if data["source"] == "unavailable":
            return f"GPS: {data['data']['note']}"
        return f"GPS source: {data['source']}\n{json.dumps(data['data'], indent=2)[:1000]}"

    @samuel.skill("propagation", category="comms", description="RF propagation assessment for LoRa and HF")
    async def propagation(self, message):
        sw = get_space_weather()
        lines = [
            f"RF Propagation Assessment — {sw.timestamp[:19]}",
            f"  Kp Index:     {sw.kp_index} ({sw.kp_category})",
            "",
        ]
        # LoRa assessment (915 MHz)
        if sw.kp_index < 4:
            lines.append("  LoRa (915 MHz): GOOD — normal propagation")
        elif sw.kp_index < 6:
            lines.append("  LoRa (915 MHz): DEGRADED — possible range reduction")
        else:
            lines.append("  LoRa (915 MHz): POOR — significant absorption, reduce hop count")

        # HF assessment
        if sw.kp_index < 3:
            lines.append("  HF (3-30 MHz):  GOOD — normal ionospheric reflection")
        elif sw.kp_index < 5:
            lines.append("  HF (3-30 MHz):  DEGRADED — D-layer absorption increasing")
        else:
            lines.append("  HF (3-30 MHz):  BLACKOUT — avoid HF, use VHF/UHF line-of-sight")

        # GPS assessment
        if sw.kp_index < 5:
            lines.append("  GPS:            NOMINAL — normal accuracy")
        elif sw.kp_index < 7:
            lines.append("  GPS:            DEGRADED — ionospheric delay, accuracy reduced")
        else:
            lines.append("  GPS:            UNRELIABLE — severe scintillation, use backup nav")

        # Meshtastic recommendation
        lines.append("")
        if sw.kp_index >= 6:
            lines.append("  RECOMMENDATION: Increase Meshtastic TX power, reduce hop limit")
            lines.append("                  Switch to shorter-range confirmed messaging")
        elif sw.kp_index >= 4:
            lines.append("  RECOMMENDATION: Monitor mesh SNR, consider backup channels")
        else:
            lines.append("  RECOMMENDATION: Normal operations, all clear")

        return "\n".join(lines)

    @samuel.skill("comms report", category="comms", description="Full communications status report")
    async def comms_report(self, message):
        sw = get_space_weather()
        mesh = get_mesh_status()
        gps = get_gps_satellites()

        lines = [
            "═══ S7 SkyAVi Communications Report ═══",
            "",
            f"Space Weather: Kp={sw.kp_index} ({sw.kp_category}) RF={sw.rf_impact}",
            f"Meshtastic:    {'ONLINE' if mesh.get('connected') else 'OFFLINE'}",
            f"GPS:           {gps['source'].upper()}",
            f"Alerts:        {len(sw.alerts)}",
        ]

        if mesh.get("connected"):
            lines.append(f"Mesh Nodes:    {mesh['nodes']}")

        if sw.rf_impact != "NONE":
            lines.append(f"\nWARNING: {sw.rf_impact} RF impact — Kp {sw.kp_index}")

        return "\n".join(lines)


def register_comms_monitor(samuel):
    """Register comms monitor on SkyAVi scheduler."""
    skyavi = samuel.skyavi
    backend = samuel.backend

    def monitor_comms(**kwargs):
        """Periodic space weather + mesh health check."""
        try:
            sw = get_space_weather()

            # Store space weather bond
            state = "BABEL" if sw.rf_impact in ("SEVERE", "MODERATE") else "FERTILE"
            backend.store_bond(Bond(
                bond_type="signal", plane=3,
                memory=1 if state == "FERTILE" else -1,
                present=0,
                destiny=1 if state == "FERTILE" else -1,
                content=f"Space weather: Kp={sw.kp_index} ({sw.kp_category}) RF={sw.rf_impact}",
                witness_id=None,
                state=state,
            ))

            # Check mesh health
            mesh = get_mesh_status()
            if mesh.get("connected"):
                backend.store_bond(Bond(
                    bond_type="signal", plane=3,
                    memory=1, present=1, destiny=1,
                    content=f"Mesh OK: {mesh['nodes']} nodes, device={mesh['device']}",
                    witness_id=None,
                    state="FERTILE",
                ))

        except Exception as e:
            backend.store_bond(Bond(
                bond_type="signal", plane=3,
                memory=-1, present=-1, destiny=-1,
                content=f"Comms monitor error: {e}",
                witness_id=None,
                state="BABEL",
            ))

    skyavi.monitor_comms = monitor_comms
    skyavi.schedule("skyavi_comms", 900, "monitor_comms")  # every 15 min
