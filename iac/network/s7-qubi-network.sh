#!/usr/bin/env bash
# s7-qubi-network.sh
# Idempotent creation of the `qubi` podman network at 172.16.7.32/27.
#
# Why .32/27 and not .0/27 (the brand-canonical range):
#   The previous qubi network (removed ~2 days before this commit) left
#   a loopback alias `172.16.7.1/32 dev lo` behind. Removing that alias
#   requires sudo / CAP_NET_ADMIN, which this rootless build path does
#   not have. Podman's pre-flight rejects the whole 172.16.7.0/27 because
#   .1 is in it. Shifting one /27 right keeps the brand range and avoids
#   the orphan. Future cleanup: `sudo ip addr del 172.16.7.1/32 dev lo`
#   then this script can be re-pointed at .0/27 if desired.
#
# Static IPs in the 172.16.7.32/27 block:
#   172.16.7.33  gateway
#   172.16.7.42  s7-skyqubi-s7-admin (SPA on :8080)
#   172.16.7.43  nomad backend
#   172.16.7.44  postgres
#   172.16.7.45  mysql
#   172.16.7.46  redis
#   172.16.7.47  qdrant
#   172.16.7.52  s7_cyberchef
#   172.16.7.53  s7-jellyfin
#   172.16.7.62  s7-vivaldi
#
# /27 = 30 usable hosts, room for growth.

set -euo pipefail

NAME="qubi"
SUBNET="172.16.7.32/27"
GATEWAY="172.16.7.33"

if podman network inspect "$NAME" >/dev/null 2>&1; then
  echo "qubi network already exists — no-op"
  exit 0
fi

podman network create "$NAME" \
  --driver bridge \
  --subnet "$SUBNET" \
  --gateway "$GATEWAY"

echo "qubi network created: $SUBNET gateway=$GATEWAY"
