#!/usr/bin/env bash
# iac/immutable/advance-immutable.sh
#
# The CORE yearly update ceremony for the S7 SkyQUB*i* immutable
# fork. Produces a signed git bundle from private/main, registers
# it, and invokes rebuild-public.sh to rebuild public from the new
# immutable.
#
# STUB STATUS (2026-04-14): this script refuses to run. It exists
# as a documentation anchor. The first immutable advance ceremony
# is a HUMAN ceremony requiring Jamie + Tonya + the image-signing
# key + a completed council round. It is not automated; this
# script is the scaffold the ceremony will eventually execute.
#
# Usage:
#   ./advance-immutable.sh --help    # print the ceremony steps
#   ./advance-immutable.sh           # ABORTS — refuses to run
#
# See CHEF Recipe #4 for the full architecture:
#   docs/internal/chef/04-immutable-fork-public-rebuild.md

set -uo pipefail

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  cat <<'HELP'

  ╔═══════════════════════════════════════════════════════════════╗
  ║   S7 Immutable Fork Advance Ceremony                          ║
  ║   CORE Yearly Update — Jamie + Tonya + image-signing key      ║
  ╚═══════════════════════════════════════════════════════════════╝

  The advance ceremony is NOT a script run. It is a human-led
  tier-crossing decision with these steps, in order:

    1. Run iac/audit/pre-sync-gate.sh. Must be green. All pinned
       items reviewed by the council and either resolved or carried
       forward with named reason.

    2. Convene a council round (CHEF Recipe #2, Bible Architecture
       Multi-Agent Council) on the question "is this private/main
       state ready to become the next canonical immutable?" Two
       rounds minimum per the Chair code-of-conduct.

    3. Freeze the candidate private/main sha by pinning it in
       iac/audit/frozen-trees.txt. Re-run the audit gate. Still
       green.

    4. Tonya signs. Per-persona signs for any voice or LYNC
       changes; per-system sign for the whole advance. If Tonya
       does not sign, the advance stops.

    5. Produce the bundle:
          git bundle create /s7/immutable/S7-QUBi-IMMUTABLE-v<year>.bundle \
              <candidate-sha>

    6. Sign the bundle with the image-signing key:
          gpg --detach-sign --armor --output <bundle>.sig <bundle>

    7. Append a new entry to iac/immutable/registry.yaml with the
       version, ISO8601 date, private_main_sha, bundle_path,
       bundle_sha256, signature_path, public_manifest_sha256,
       tonya_signoff, council_round link, advanced_by, retires,
       frozen_trees_pin_update, notes.

    8. Retire the prior immutable (if any) by setting its `retires`
       field to the new version.

    9. In the same commit as step 7+8: remove the public/main line
       from iac/audit/frozen-trees.txt (public is now a function of
       the immutable, not a tracked branch).

   10. In the same commit: manually retire the `immutable-registry-
       empty` entry in iac/audit/pinned.yaml. The pin transition
       rule is: whoever creates the first registry entry is also
       responsible for removing the registry-empty pin in the same
       commit. This is the PINNED transition protocol (Round 2
       Skeptic catch).

   11. Commit this whole set on lifecycle; fast-forward to
       private/main.

   12. Invoke rebuild-public.sh (no arguments — it reads the latest
       non-retired registry entry). This is the only time public/
       main moves. The rebuild is deterministic.

   13. Run audit zero #12. Must be green. If not, the rebuild
       failed and the advance is rolled back by reverting the
       registry commit; the bundle and signature remain on disk
       for investigation.

   14. Close the council round with the advance record.

  THE GATEKEEPER:
    The ceremony does not have a single script gatekeeper. The
    authorizing witnesses are, in order:
      - The audit gate (zeros 1-12)
      - The council round (Chair + Skeptic + Witness + Builder)
      - Tonya's signature (covenant veto)
      - The image-signing key (cryptographic witness)
    If any of the four refuses, the ceremony halts. There is no
    single point of authorization because there is no single point
    of trust.

  THE SYNC-TO-CEREMONY HANDOFF:
    Until the first ceremony completes, s7-sync-public.sh is the
    source of truth for public/main. At the moment the first
    ceremony's rebuild-public.sh force-push completes successfully,
    s7-sync-public.sh yields authority and is renamed to
    s7-sync-public.sh.retired with a header comment pointing at
    CHEF Recipe #4. Deleting it is a later-session cleanup.

  RECIPE:
    docs/internal/chef/04-immutable-fork-public-rebuild.md
  COUNCIL TRANSCRIPT:
    docs/internal/chef/council-rounds/2026-04-14-immutable-fork-architecture.md

HELP
  exit 0
fi

echo
echo "  🔴 REFUSED — this script is a stub."
echo
echo "  The first Immutable Advance ceremony is a HUMAN ceremony"
echo "  requiring Jamie + Tonya + image-signing key + completed"
echo "  council round. It cannot be initiated by running this script."
echo
echo "  Pass --help to see the ceremony steps."
echo "  See CHEF Recipe #4 for the full architecture."
echo
exit 1
