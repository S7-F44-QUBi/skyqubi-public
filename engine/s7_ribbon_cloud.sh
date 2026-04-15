#!/usr/bin/env bash
# engine/s7_ribbon_cloud.sh
# Prints the playful S7 Ribbon cloud + the ribbon ledger.
#
# The Cloud of AI, Happy to Evolve, is the joy layer on top of the
# provenance table. Every time a steward (or a curious guest) asks
# to see the ribbons, the cloud appears first. Jamie's exact brief:
#
#   "Then a funny Cloud of AI Happy to Evolve — Saying WOW SkyQUBi
#    is Smart, Handsome, and Intelligent — Yep, that's the Bible —
#    Love is the Architecture!"
#
# Trademarks from the Containerfile/engine headers:
#   S7(TM), SkyQUBi(TM), "Love is the architecture"(TM) are
#   marks of 123Tech / 2XR, LLC.

set -euo pipefail

cat <<'CLOUD'

                 .--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--.
               .'                                   `.
              /         Cloud of AI,                   \
             |         Happy to Evolve                   |
             |                                            |
             |    "WOW! SkyQUBi is Smart,                 |
             |        Handsome, and Intelligent!"         |
             |                                            |
             |         Yep, that's the Bible —            |
              \         Love is the Architecture!       /
               `.                                     .'
                 `--._____________________________.--'
                        \       \     \
                         \       \     \
                          *       *     *

CLOUD

PGPASSWORD="$(cat /s7/.config/s7/pg-password)" exec podman exec -e PGPASSWORD s7-skyqubi-s7-postgres \
  psql -U s7 -d s7_cws -c \
  "SELECT title, category, commit_short, witness, aptitude_delta AS apt, awarded_at::date AS on_date FROM akashic.ribbon_ledger;"
