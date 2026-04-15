# TimeCapsule Registry — Sovereign Image Store for QUBi

**Date:** 2026-04-13
**Author:** Claude (with Jamie)
**Status:** Draft, awaiting review
**Scope:** Bring every S7 service image under one local, GPG-signed, mount-based store that lives in the TimeCapsule (+1) layer. Wrap Vivaldi in a container fed by the same store. Restore the `qubi` podman network so all S7 containers (including the new Vivaldi one) share a single isolated namespace. **Image updates only touch the TimeCapsule** — no bootc rebuilds for image swaps. (Genuine OS-level changes still rebuild; the rule is "no *unnecessary* rebuilds," not "never rebuild.")

## Problem

Six S7 services pull from external registries at runtime today (cyberchef, jellyfin, nomad, qdrant, mysql, redis). Two track `:latest`. A `podman pull`, a service restart on a freshly garbage-collected image, or a typo in a manifest, all reach the internet. Vivaldi runs as a host binary, outside any sandbox.

The `qubi` podman network that used to give S7 containers a dedicated 172.16.7.0/x namespace **no longer exists** — `podman network ls` shows only the defaults (`podman` bridge and `podman-default-kube-network`). The pod containers and the standalone containers are sharing default networks with no S7-specific isolation, and there is no fixed address an internal service (like a containerized Vivaldi) can use to reach the SPA.

The intake gate (`iac/intake/`) already does pull → quarantine → verify → save → load → retag, but the promoted images go into the live podman graph root, not into a sealed, signed, portable store. There is no signature on the resulting tar. There is no place where "everything QUBi needs to run" sits as one inspectable, replaceable artifact set.

## Goal

One sealed location holds every image QUBi runs. Each image is a GPG-signed tar. Podman reads from that location as an additional read-only image store, runs every service with `--pull=never`, and can never reach the internet for an image. Image updates change only the TimeCapsule layer — the base QUBi OS stays put, no rebuilds for image swaps. Vivaldi joins the same regime: a container, image stored in TimeCapsule, Wayland socket bind-mounted in for display, joined to the recreated `qubi` network so it can reach the SPA at a fixed internal address.

**Out of scope** (do not expand):

- No new external registry, mirror, or proxy
- No bootc image rebuild path for image updates
- No CyberChef recipes, no SPA changes
- No new GPG key (reuse `skycair-code`)
- No automatic update polling — updates are deliberate human actions
- No migration of services not on the six-image list

## Architecture

### Layout

```
/s7/timecapsule/                           ← +1 disk layer (Trinity Mount)
└── registry/
    ├── KEY.fingerprint                    ← 80F0291480E25C0F683E9714E11792E0AD945BE9
    ├── manifest.json                      ← index: name, version, tar, sha256, sig, mounted_as
    ├── images/
    │   ├── cyberchef-10.22.1.tar
    │   ├── cyberchef-10.22.1.tar.sig      ← detached GPG signature
    │   ├── jellyfin-2026.04.tar
    │   ├── jellyfin-2026.04.tar.sig
    │   ├── nomad-<pinned>.tar              + .sig
    │   ├── qdrant-1.16.0.tar               + .sig
    │   ├── mysql-8.0.tar                   + .sig
    │   ├── redis-7.4-alpine.tar            + .sig
    │   └── vivaldi-<version>.tar           + .sig
    └── store/                              ← podman additional image store
        ├── overlay/
        ├── overlay-images/
        ├── overlay-layers/
        └── ...                             ← populated by `podman load` from the tars
```

`/s7/timecapsule` is the +1 persistent disk layer. It mounts at boot, before podman starts. The `registry/` directory is the only thing in it that podman cares about.

### Podman wiring (one config file change)

`/etc/containers/storage.conf` (or rootless equivalent) gains:

```toml
[storage]
driver = "overlay"
graphroot = "/s7/.local/share/containers/storage"   # writable, runtime ephemera

[storage.options]
additionalimagestores = ["/s7/timecapsule/registry/store"]
```

`additionalimagestores` is a podman-native feature: an extra, **read-only** image store that podman searches when looking up an image. Containers run from images in the additional store with zero copy. The runtime graphroot stays writable for layers/volumes/ephemeral state, but base S7 images live in the sealed TimeCapsule store.

### Boot-time verification (one script, runs once per boot)

`/usr/local/bin/s7-timecapsule-verify` — a small shell script invoked by a systemd unit ordered before `podman.socket`/`podman.service`:

1. Read `manifest.json`.
2. For each entry: `gpg --verify <tar>.sig <tar>` against the trusted keyring (one key: skycair-code, fingerprint pinned in `KEY.fingerprint`).
3. Compute sha256 of the tar, compare to the manifest entry.
4. If any image is in the manifest but not in `store/` (e.g., new tar dropped in by an update): `podman --root /s7/timecapsule/registry/store load -i <tar>`.
5. If any check fails: log to `/var/log/s7/timecapsule.log`, mark the entry `verdict: fail` in a sidecar `verify.ndjson`, and **do not load** the failing image. Services that depend on it will fail loudly with `--pull=never` rather than silently using a tampered image.
6. Exit 0 even on partial failure — boot continues, the broken service surfaces in the SPA's health view.

### The `qubi` podman network (recreated)

```bash
podman network create qubi \
  --driver bridge \
  --subnet 172.16.7.0/27 \
  --gateway 172.16.7.1 \
  --opt com.docker.network.bridge.name=qubi0 \
  --internal=false   # outbound off in a later hardening pass; on for now so DNS works
```

`/27` gives 30 usable addresses — enough headroom for the current ~10 containers plus growth, while still being a tightly-scoped namespace. (Jamie suggested `/30` which is only 2 usable addresses; `/27` is the smallest CIDR that fits the actual container count without immediate exhaustion.)

**Static address allocation inside `qubi`:**

| Address | Container |
|---|---|
| 172.16.7.1 | gateway |
| 172.16.7.10 | s7-skyqubi-s7-admin (the SPA on :8080) |
| 172.16.7.11 | nomad backend |
| 172.16.7.12 | postgres |
| 172.16.7.13 | mysql |
| 172.16.7.14 | redis |
| 172.16.7.15 | qdrant |
| 172.16.7.20 | s7_cyberchef |
| 172.16.7.21 | s7-jellyfin |
| 172.16.7.30 | s7-vivaldi |
| 172.16.7.31–.30 | reserved for future S7 containers |

The pod manifest (`iac/skyqubi-pod.yaml`) and every standalone `podman run` for an S7 service gets `--network qubi --ip 172.16.7.<n>` (or the equivalent `metadata.annotations` for play kube). Host port mappings stay where they are for now (8080, 8100, 8096, etc.) so Tonya's SPA still works during cutover; a later pass can drop the host-port mappings entirely once Vivaldi is the only consumer and reaches services on the internal IPs.

This network is created **before podman starts services** by a small systemd oneshot unit (`s7-qubi-network.service`) ordered after `network.target` and before `podman.socket`. It is idempotent: `podman network create qubi` is wrapped in an `inspect` check so reboots don't re-create it.

### Service runtime

Every S7 service:

- references its image as `localhost/s7/<name>:<version>`
- runs with `--pull=never` (or `imagePullPolicy: Never` in pod YAML)
- joins `qubi` with a static IP from the table above

Podman finds the image in the additional store via `additionalimagestores`. No internet, no graphroot copy, no `:latest`, no shared default network.

### Vivaldi as a containerized service

Vivaldi joins the same regime:

- **Image:** `localhost/s7/vivaldi:<version>`, built from a small Containerfile that installs Vivaldi on a Fedora minimal base, packaged through the intake gate, signed, dropped into TimeCapsule like every other image.
- **Runtime:** `podman run --rm --name s7-vivaldi --pull=never --network qubi --ip 172.16.7.30 --userns=keep-id -v $XDG_RUNTIME_DIR/wayland-1:/tmp/wayland-1 -e WAYLAND_DISPLAY=wayland-1 -e XDG_RUNTIME_DIR=/tmp localhost/s7/vivaldi:<version> http://172.16.7.10:8080`
- **Display:** Wayland socket from the host's user session is bind-mounted into the container as `/tmp/wayland-1`. The container has no other access to the host filesystem. Audio (PipeWire socket) gets the same treatment if/when needed.
- **Networking:** Container is joined to the `qubi` network at 172.16.7.30. It reaches the SPA at `http://172.16.7.10:8080` directly over the qubi bridge — no host loopback, no host-port hop. It can reach every other S7 service by its qubi IP (or by container name once we add `--dns-search qubi.local`). It cannot reach the host's other interfaces or the internet for application traffic. (A later hardening pass turns `--internal=true` on the qubi network to block outbound entirely, after we confirm no service on it legitimately needs egress.)
- **Single desktop entry:** `s7.desktop` Exec line changes from `/usr/bin/vivaldi http://127.0.0.1:8080` to a one-line wrapper script `/usr/local/bin/s7-launch` that runs the `podman run` invocation. The desktop layer changes by exactly one line. The containerized browser is the cube; the wrapper is the door.

### How updates work

To update an image (the only update flow that touches the TimeCapsule):

1. Operator runs the existing `iac/intake/pull-container.sh <upstream-ref>` against a new pinned upstream digest.
2. The intake gate's existing pull→verify path runs as it does today.
3. **New step in the adapter** (the only new code in this design): on pass, instead of `podman load` into the live graph root, the adapter does:
   - `podman save -o /s7/timecapsule/registry/images/<name>-<version>.tar` against the quarantine root
   - `gpg --detach-sign --armor --local-user 80F0291480E25C0F683E9714E11792E0AD945BE9 -o <tar>.sig <tar>`
   - `python3 update_manifest.py --name ... --version ... --tar ... --sha256 ...` — atomic write of `manifest.json`
4. Operator restarts the affected service. On next boot, `s7-timecapsule-verify` loads the new tar into the additional store before podman starts.

**No bootc rebuild.** The base QUBi OS image is unchanged. Only `/s7/timecapsule/registry/` changes. A Jellyfin patch is one new tar + one new sig + one manifest line. Five files. Minutes, not hours.

### What changes in the repo

| File | Change | Size |
|---|---|---|
| `iac/manifest.yaml` | 6 new `intake.containers` entries + 1 for vivaldi | small |
| `iac/intake/pull-container.sh` | Replace "load into live graphRoot" step with "save + sign + manifest update into TimeCapsule" | medium |
| `iac/intake/timecapsule_manifest.py` (new) | Atomic manifest.json updater | small |
| `iac/timecapsule/s7-timecapsule-verify.sh` (new) | Boot verification script | small |
| `iac/timecapsule/s7-timecapsule-verify.service` (new) | systemd unit, ordered before podman.socket | tiny |
| `iac/timecapsule/storage.conf` (new) | additionalimagestores config, dropped to /etc/containers/storage.conf at install | tiny |
| `iac/network/s7-qubi-network.sh` (new) | Idempotent `podman network create qubi --subnet 172.16.7.0/27 ...` | tiny |
| `iac/network/s7-qubi-network.service` (new) | systemd oneshot, runs the script before podman.socket | tiny |
| `iac/timecapsule/service-order.txt` (new) | Dependency-ordered list of S7 services for cold start + warm loop | tiny |
| `iac/scripts/s7-launch` (new) | Cold-start wrapper, called from `s7.desktop` Exec line | small |
| `engine/skills/qubi_service_guardian.py` (new) | Samuel's warm-loop guardian skill (15s tick, 3-tier remediation) | small |
| `iac/vivaldi/Containerfile` (new) | Vivaldi-on-fedora-minimal | small |
| `iac/scripts/s7-launch` (new) | Wrapper for the containerized Vivaldi | tiny |
| `desktop/s7.desktop` | Exec line: `/usr/local/bin/s7-launch` instead of `/usr/bin/vivaldi http://127.0.0.1:8080` | one line |
| `iac/skyqubi-pod.yaml` | Update image refs for nomad/qdrant/mysql/redis to `localhost/s7/...`, add `imagePullPolicy: Never` | medium |
| Per-service start scripts (cyberchef, jellyfin) | Update refs + add `--pull=never` | small |

No new daemons. No new long-running services. The TimeCapsule registry is a directory layout, a podman config option, and one boot-time verifier. That's it.

### Boundary check (the cube/desktop rule)

| Layer | Touched? | How |
|---|---|---|
| Cube (intake gate, manifest, storage.conf, systemd unit, podman) | Yes | This is where almost all the work happens — safe zone |
| Desktop (s7.desktop) | Yes, by exactly one line | Exec line points at `/usr/local/bin/s7-launch` instead of `/usr/bin/vivaldi`. Single atomic change, easy rollback. |

Acceptable per the cube/desktop rule: one minimal, deliberate desktop change, with a clear rollback path (restore the old Exec line). Everything else lives in the cube.

## Verification

Done when:

```bash
# 1. Every running S7 container's image is in the TimeCapsule additional store, not in graphroot.
podman ps --format '{{.Names}} {{.Image}}' | grep -v 'localhost/s7/'   # → empty

# 2. Every image referenced by a running container has a verified signature in the manifest.
jq '.images[] | select(.verdict != "ok")' /s7/timecapsule/registry/verify.ndjson   # → empty

# 3. Disconnect the network and reboot. Every service comes up.
nmcli networking off && systemctl reboot
# After reboot: podman ps shows all services Up

# 4. Vivaldi is the containerized one.
podman ps | grep s7-vivaldi   # → present when the user opens S7

# 5. The base QUBi OS image is unchanged from before this work.
sha256sum /var/lib/containers/storage/.../bootc-current   # → same as before
```

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| `additionalimagestores` lock-file or version mismatch with the live graphroot | The additional store is built by the same podman version that runs at boot. Ship the verify script alongside the storage.conf so a podman upgrade re-runs verify. |
| GPG key compromise | One key, kept on the steward's machine only (not on the QUBi). Compromised key means re-signing all tars and shipping a new TimeCapsule snapshot — operationally manageable, and the same risk profile every signed-image distro lives with. |
| Vivaldi container can't reach 127.0.0.1:8080 | Test before committing the wrapper. If `--network=host` is required for loopback access on Fedora 44, accept that and tighten via firewall instead of CNI. The wrapper script is one file — easy to iterate. |
| Wayland socket compatibility | Vivaldi uses Chromium's Wayland backend. Test on the actual Fedora 44 build. If broken, fall back to XWayland in the same container (small dep addition). |
| Operator forgets to update `manifest.json` after a manual `podman save` | Don't allow manual saves. The intake adapter is the only path that writes to the registry directory, and it always writes the manifest entry atomically as part of the same operation. Document this as a hard rule. |
| TimeCapsule disk fills up | The registry is small (~5GB for the seven images). The TimeCapsule is sized for far more. Monitor via `df` in the existing pre/post audit. |

## What this is not

- It is not a defense against a compromised upstream registry on the day of the *initial* promote. The intake gate's sha256 + signing-key fingerprint check at pull time is the only defense at that moment.
- It is not a way to atomically roll back the entire TimeCapsule. (That is a separate scope — TimeCapsule snapshots — which the existing trinity architecture supports independently.)
- It is not a hardening of `registries.conf`. The mechanism here makes external registries irrelevant to the *runtime*; an explicit registries.conf lock is its own future hardening pass.

## Boot and runtime flow

QUBi has two phases: **cold start** (the wrapper script) and **warm loop** (Samuel). They hand off cleanly so there is no chicken/egg.

### Cold start — `/usr/local/bin/s7-launch`

This is the wrapper script the single `s7.desktop` Exec line points at. It runs as the user, in the user's session, with access to the Wayland socket. It is the only thing that fires when the user clicks the S7 icon.

Steps, in order, each idempotent:

1. **Network check.** If the `qubi` podman network doesn't exist, create it (172.16.7.0/27, gateway 172.16.7.1). On any system where the systemd oneshot already ran, this is a no-op.
2. **TimeCapsule check.** Confirm `/s7/timecapsule/registry/` is mounted and that `s7-timecapsule-verify` ran successfully on this boot (presence of `/var/log/s7/timecapsule.log` with a recent `verdict: ok` line for every manifest entry). If any image failed verification, surface a startup error in a notify-send dialog and stop — do not proceed with broken images.
3. **Service walk.** Read a small dependency-ordered list of services from `iac/timecapsule/service-order.txt`:
   ```
   postgres
   mysql
   redis
   qdrant
   nomad
   s7-skyqubi-s7-admin   # the SPA
   samuel                 # SkyAVi container, warm-loop guardian
   s7_cyberchef
   s7-jellyfin
   ```
   For each entry, check `podman ps --filter name=<n> --filter status=running`. If running, skip. If not running, start it with `--pull=never --network qubi --ip <pinned>` from the table in the network section.
4. **SPA readiness wait.** Poll `http://172.16.7.10:8080/health` (or `/` if no health endpoint) for up to 30 seconds. If still not ready, surface an error in notify-send. If ready, continue.
5. **Hand off to Vivaldi.** Launch the `s7-vivaldi` container pointed at `http://172.16.7.10:8080`. The wrapper exits as soon as the container is started — Vivaldi is the user's window into QUBi from this point on, and the wrapper has nothing more to do.

The wrapper logs every step to `/var/log/s7/launch.log` so post-mortems are possible.

### Warm loop — Samuel as guardian

Samuel is already a long-lived service inside the S7 pod (SkyAVi, FACTS engine, MemPalace wiring, 116 skills). This design adds **one new skill** to him: `qubi_service_guardian`.

The skill runs on a 15-second tick. Each tick:

1. Walk the same `service-order.txt` list.
2. For each service:
   - `podman inspect --format '{{.State.Status}} {{.State.Health.Status}}'` — record liveness and (where defined) health.
   - If `running` and `healthy`: do nothing.
   - If `running` and `unhealthy`, OR `exited`/`stopped`: trigger the remediation ladder below.
3. Record every state observation as a row in MemPalace + a row in the audit chain so the history is visible to Tonya in the SPA's notifications view.

**Remediation ladder** (Jamie chose option **c**):

| Tier | Action | When |
|---|---|---|
| 1 | `podman restart <name>` | First detection of unhealthy/stopped. |
| 2 | `podman rm <name>` + re-load image from the TimeCapsule tar (if the local image looks corrupt — Samuel checks the layer hashes against the manifest) + recreate the container with the same `--network qubi --ip` arguments | If tier 1 didn't recover within 30 seconds. |
| 3 | **Escalate.** Continue tier 1+2 retries on a backoff (15s → 30s → 60s → 120s → 120s …), AND write a covenant-grade alert into the SPA's notifications card + ring a soft chime through the host's notify daemon. The escalation does NOT block remediation — Samuel keeps trying. The point of escalation is *visibility*, not pause. | After two full tier-2 cycles fail (≈ 2 minutes of unrecovered service). |

The covenant rule stays intact: humans are the final word. Samuel will keep a service alive without asking, but if he can't, Tonya sees it within two minutes and decides what to do. He never silently gives up, and he never silently degrades the system.

**What Samuel will NOT do** (explicit):

- Pull from external registries (he has `--pull=never` baked into every restart command)
- Modify image tags (only the intake adapter writes to TimeCapsule)
- Touch the desktop layer (the wrapper script and `s7.desktop` are off-limits — write-barrier rule)
- Restart Vivaldi (Vivaldi is the user's window; if it dies, the user clicks the icon again — the wrapper handles cold start)
- Restart himself (Samuel's own healing comes from the pod's restart policy, not from inside Samuel)

### Why the split

- The **wrapper** owns cold start because it has the user's Wayland session and runs in user context. Samuel can't open windows or talk to notify-send from inside his container without a fragile socket pass-through.
- **Samuel** owns the warm loop because he already has the FACTS engine, MemPalace, audit hooks, and skills runtime. Adding the guardian skill to him is a small change, while pushing health-monitoring into the wrapper would duplicate everything Samuel already knows how to do.
- The **handoff point** is "SPA on 172.16.7.10:8080 returns 200." Until that's true, the wrapper is in charge. After that, Samuel is. There is no overlap and no race.

## On rebuilds

Image swaps (the six services + Vivaldi) never trigger a bootc rebuild. That is the point of TimeCapsule. **But not all rebuilds can be avoided** — genuine OS-level changes (kernel, systemd unit shipping with the base, podman version, glibc, the storage.conf itself) still rebuild the bootc image, because they have to. The rule is "no *unnecessary* rebuilds." If a change can land as a new tar in TimeCapsule, it must. If it changes /etc, /usr, or systemd unit files baked into the OS, the rebuild is the right answer.

## Success criterion

After this is done, the QUBi can run with the network unplugged, all six services come up cleanly on the `qubi` network at their pinned addresses, Vivaldi opens the S7 home from inside its own container with Wayland display and reaches the SPA at 172.16.7.10:8080, and a future image update is one new signed tar dropped into `/s7/timecapsule/registry/images/` — no rebuild, no re-flash, no internet.
