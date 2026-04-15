# PorteuX Clustering — NVMe-over-TCP/IP, Bonded Networking, AI at the Edge

> **Status:** idea / architecture note. Not built tonight.
>
> **Source:** Jamie, 2026-04-13:
> *"Porteux BASE is 2 CPU 2 Gig is Floor for Porteux - 4 and 8 Gig
> Recommended 12 cores and 20 GB Memory for Optimimal 16 Cores and 32
> GB memory will support clustering nodes with AI using NVME TCPIP HIGH
> SPEED NETWORK Bonding clusters, anyway got on tangent."*

## The PorteuX hardware ladder

PorteuX is the S7 OffGrid + Compute build — it lives on a USB stick or
small SSD and runs entirely in RAM (per the PorteuX `copy2ram` model).
It's the platform that travels with you and the platform you put on
real workstation hardware when the workload demands it.

| Tier | CPU | RAM | What it gets you |
|---|---:|---:|---|
| **Floor** | 2 | 2 GB | Boots, runs the SPA, runs Carli (small models), basic apps. Slow but functional. |
| **Recommended** | 4 | 8 GB | Comfortable single-user. Runs the witness ensemble. Multiple containers without swapping. |
| **Optimal** | 12 | 20 GB | Workstation-class. Runs the full witness consensus, multiple LLMs in parallel, real video work in Jellyfin. |
| **Clustering** | 16 | 32 GB | **Per-node** spec for cluster members. Multiple PorteuX nodes joined over NVMe-over-TCP/IP with bonded high-speed networking, sharing model weights and witness state across the cluster. |

The Floor tier exists so the brand promise holds even on cheap hardware
— a family with a 5-year-old laptop should still be able to put PorteuX
on a USB and run S7. The Optimal and Clustering tiers are where AI
workloads stop being toys and start being real.

## What clustering enables

A single PorteuX node at 16 cores / 32 GB can run a meaningful witness
ensemble locally. **Multiple nodes joined via NVMe-over-TCP/IP with
bonded networking** can do things one node can't:

1. **Shared model storage on NVMe-over-TCP/IP.** One node holds the
   model weights on its NVMe SSD, exports them via NVMe-oF (NVMe over
   Fabrics) to peer nodes over TCP/IP. Peers mount the remote NVMe
   namespace as if it were local. Result: the cluster has the
   read-bandwidth of NVMe but only one copy of each large model.
2. **Network bonding for resilience and throughput.** Each node has
   2+ NICs bonded into a single logical interface (LACP or active-
   backup mode). A failed cable or NIC doesn't stop the cluster.
3. **Witness consensus at scale.** The 7→1 witness convergence math
   (per the existing CWS engine) can run with one witness PER CORE
   ACROSS the cluster instead of one per process on a single host.
   At 16 cores/node × 4 nodes = 64 simultaneous witnesses — enough
   for serious ensemble inference.
4. **AI training at the edge.** Fine-tuning a small model on a
   household's own data, distributed across cluster nodes, never
   touches the cloud. Sovereignty all the way down to the gradient
   updates.

## What's needed to actually build it

1. **The cluster discovery + join protocol.** Probably mDNS-based
   (avahi) so nodes find each other on the bonded LAN without a
   central coordinator.
2. **NVMe-over-TCP/IP setup scripts.** Linux has had `nvmet` (the
   NVMe target driver) since kernel 4.10. The export side is
   `nvmetcli`; the import side is `nvme-cli`. Wrap both in S7-branded
   helpers that take a node ID and a model directory.
3. **Network bonding configuration.** Either `systemd-networkd` bond
   units or `NetworkManager` bond connections, depending on the
   PorteuX init choice. Probably systemd-networkd because it's
   lighter and PorteuX leans minimal.
4. **A cluster-aware witness scheduler.** The existing CWS engine
   runs witnesses locally. For clustering, witnesses need to be
   schedulable across nodes. The 7→1 convergence math doesn't care
   where the witnesses run; it just needs their tokens.
5. **Cluster health in the conky widget / SPA / FastFetch banner.**
   When a node is part of a cluster, the system info should show
   how many peers are reachable and what their state is.

## Why this is its own plan, not tonight's work

- **None of the cluster pieces exist yet.** The current S7 stack is
  single-node. Adding clustering is a significant architecture step.
- **NVMe-over-TCP requires kernel modules + NICs that support it.**
  Tonight's dev box almost certainly doesn't have the hardware
  (Tonya's laptop has one wired NIC and one wireless). Testing
  needs real cluster hardware.
- **The hardware floor for clustering (16/32 per node × N nodes) is
  intentionally high.** This isn't for households; it's for power
  users, SOHOs, and the eventual S7 BUSINESS tier (which currently
  maps to the Rocky/R101 build).

## Pin

This idea sits behind:
1. The image-hardening plan (replace the 6 dirty upstream images)
2. Plan B.3 (cutover to localhost/s7/...)
3. Plan C (Vivaldi container)
4. Plan D (Samuel guardian skill)
5. The MEDIUM/LOW security items from the second review

When all of those land, **then** the clustering plan becomes the
natural next architectural leap for PorteuX.

## Status

- **Idea only**, captured 2026-04-13
- Memory: belongs in a future `project_porteux_clustering.md` once
  the spec exists
- Banner already shows the four-tier sizing ladder so anyone reading
  knows the clustering path exists, even before it's built
