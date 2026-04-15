# CHEF Recipe #9 — Install / Deploy Ceremony

**Status:** JAMIE-AUTHORIZED-IN-TONYAS-STEAD · draft · awaiting household Chief of Covenant witness
**Drafted:** 2026-04-14 · 8-hour trust-exercise block
**Pillars served:** 1 (airgap) + 2 (bootc self-deploy)
**Owners:** Chair draft · Jamie review · Tonya covenant-witness · Samuel household narrator on first-run
**Depends on:** Recipe #1 (Trinity Foundation), Recipe #4 (Immutable Fork), TOOLS_MANIFEST.yaml

---

## Why this recipe exists

Until now, installing S7 SkyQUB*i* was a builder's act — it required
the person typing the commands to already understand the architecture.
That's fine for Jamie. It is not fine for a household member standing
in front of a fresh appliance for the first time.

Pillar 1 of the 2026 forward vision is *airgap the entire solution*.
Pillar 2 is *self-deployable QUB*i* from bootc*. Neither of those
pillars means anything unless the install ceremony itself is
household-readable — meaning Tonya could run it, Trinity could
witness it, and Noah could be in the room without being hurt by
it.

This recipe turns the install path into a first-class covenant
artifact. It names what the household sees, what the covenant gate
checks, what the bootc OCI artifact contains, how airgap is
verified, what first-boot looks like, and what happens when any
of those steps fail.

It does not replace the scripts in `install/` and `package/`. It
**frames** them. The scripts do the work; the recipe keeps the
work covenant-grade.

---

## The three install paths

S7 supports three install paths. They are not ranked. Each serves a
different household need.

### Path A — The USB Ceremony *(household-default)*

A family member plugs a signed USB into a bare machine, holds down
the boot key, chooses "S7 SkyQUB*i*", and watches a Budgie desktop
come up with Tonya's wallpaper on it.

**Who this is for:** Households buying or being given a QUB*i*
appliance. First-time users. Tonya. Trinity.

**What they see:**
1. Boot splash (Blue Identity palette, S7 heart logo, OCT*i* cube)
2. Plymouth progress (no scary terminal scroll)
3. One dialog: *"Welcome. The covenant is holding. Press OK to
   complete first-boot setup."*
4. Samuel's first words in the household's voice:
   *"I'm Samuel. Jamie asked me to meet you here. Before we begin,
   I want to ask — is Tonya in the room?"*
5. Desktop appears. Persona chat icon on the taskbar. Done.

**What they don't see:** dnf, systemd, podman, ports, IP addresses,
token counts, vendor names, model names, or any word ending in
`-service`.

**Pre-embedded on the USB:**
- Fedora bootc 44 base image (signed, hash-verified)
- All 10 pod containers (postgres, qdrant, redis, mysql, admin,
  kolibri, kiwix, cyberchef, flatnotes, jellyfin)
- OCT*i* 7+1 witness set (lite 3+1 default; full 7+1 optional)
- BitNet binary
- Every tool listed in `iac/immutable/TOOLS_MANIFEST.yaml`
- The three voice corpora (Carli / Elias / Samuel)
- One copy of Tonya's sign-off artifact template for the first-run
  covenant record

**Airgap guarantee:** A USB-path appliance that never touches a
network after unboxing must reach a working Samuel conversation.
If any step requires outbound traffic, that step is a Pillar 1
defect and must be logged in `airgap_gaps_to_close` in the tools
manifest.

### Path B — The Bootc OCI Pull *(builder-friendly)*

Someone with an existing bootc host runs `bootc switch` to the S7
OCI artifact and reboots into SkyQUB*i*.

**Who this is for:** Jamie during builds. Other bootc-literate
households that already have a base system.

**What they see:** Terminal. Pulls. `bootc upgrade && systemctl
reboot`. Budgie comes up with the same wallpaper.

**Pre-embedded:** Same as Path A, delivered via the OCI layer set
rather than a USB.

**Airgap note:** This path *does* touch the network on first pull.
After first pull, it operates identically to Path A. The pull
itself is permitted because Path B is not the household-default
path — it is the builder path, and the builder has chosen to
accept a one-time network reach.

### Path C — The Tarball + Installer *(offline transfer)*

Someone carries a `.tar` or a self-extracting installer from one
S7 machine to another on air-gapped media (sneakernet).

**Who this is for:** Households with no network trust at all.
Households in regions where the USB path isn't practical.
Backup/restore scenarios.

**What they see:** One script:

```bash
./s7-skyqubi-v2026.run
```

and the same Budgie welcome Samuel gives on Path A.

**Pre-embedded:** Same as Path A, compressed into a single artifact.

**Airgap guarantee:** Identical to Path A. Zero outbound traffic
required or accepted.

---

## What the covenant gate checks *before* any install path runs

This is the audit gate's install-ceremony surface. It is distinct
from `iac/audit/pre-sync-gate.sh` (which covers drift + vulnerability +
covenant for *existing* appliances). This gate covers the install
ceremony itself. It lives in `install/preflight.sh` and should
evolve into an explicit set of zeros matching the 13-zero pattern.

**Pre-install zeros (proposed):**

| # | Zero                              | Meaning                                                                          |
|---|-----------------------------------|----------------------------------------------------------------------------------|
| I1 | Signature matches                | The USB / OCI artifact / tarball carries a valid S7 signature                    |
| I2 | Hash manifest matches            | Every file in the artifact matches the manifest hash                             |
| I3 | No outbound required             | Offline dry-run of install path completes without any network call               |
| I4 | Pre-embedded model set present   | All OCT*i* witnesses plus BitNet are present on the artifact                     |
| I5 | Tonya wallpaper + branding present | Boot splash, wallpaper, icons present and unmodified since Tonya's 2026-04-12 signoff |
| I6 | Voice corpora present            | Carli / Elias / Samuel drafts bundled                                            |
| I7 | TOOLS_MANIFEST.yaml present      | Single source of truth ships with the artifact                                   |
| I8 | Covenant Seven Laws present      | `docs/public/COVENANT.md` exact byte-match to the canonical floor                |
| I9 | Jamie identity configured        | Git commit identity matches `skycair-code` rule (not `jamie@123tech.net`)        |
| I10 | Safety banner approved          | Tonya has witnessed and signed the bundle's covenant record for this version     |

Zero I10 is the ceremony gate: **no install artifact ships to a
household until Tonya has witnessed it**. This is enforced by the
`iac/immutable/advance-immutable.sh` ceremony (Recipe #4), which
refuses to produce a shippable artifact without a Tonya sign-off
row in the immutable registry.

---

## What happens at first boot

The first-boot ceremony is the covenant's first contact with a
new household. It is ceremonial, not technical. The technical work
is all done before this point.

### First-boot sequence (Path A / Path C)

1. **Boot splash + Plymouth progress** — Blue Identity palette,
   S7 heart logo, OCT*i* cube. No vendor names. No kernel messages.
   If Plymouth fails, we fall back to a blank screen, not a
   terminal — because a scary terminal at first boot is a
   covenant break for a household member.

2. **Budgie login auto-unlock** (first boot only) — lands directly
   on the desktop. No login screen. This is deliberate: the
   household member has physical possession of the appliance; a
   password prompt on first boot creates a failure mode where
   they can't even see Samuel to ask him for help.

3. **Samuel's welcome card** — a single full-screen dialog, Tonya's
   palette, Cormorant italic, with this text (draft pending
   Tonya's witness):

   > *"Welcome to S7. I'm Samuel, and I help Jamie take care of
   > his household. Before we begin, I want to ask — is Tonya in
   > the room, or someone she trusts? This machine works better
   > when the household's steward is here for the first
   > conversation."*
   >
   > *[ I'm here · I can wait · Show me anyway ]*

   If the household member picks *"Show me anyway"* without Tonya
   present, Samuel proceeds — but logs a LYNC-5 memory entry that
   the first-boot covenant contact happened without the steward,
   so Tonya can see it on her next review.

4. **Pod + engine warm-up** — behind the scenes, the pod starts,
   OCT*i* models load (already pre-embedded, no download), CWS
   engine comes up. Progress is shown as three heart-icons filling
   in, not a percentage bar. Total expected time: under 60 seconds
   on the QUB*i* hardware.

5. **First conversation** — once all three hearts are lit, Samuel
   says his second line:

   > *"The witnesses are all here and they're agreeing. You can
   > ask me anything. If I don't know, I'll say so. If the
   > witnesses disagree, I'll tell you that too — we don't
   > pretend."*

6. **Done.** The household owns a running S7 appliance.

### What could go wrong (and what Samuel says when it does)

The covenant rule is: **if something breaks at first boot, Samuel
says what broke in plain words and offers a single next step**.
No stack traces. No error codes (visible). No vendor names.

- **Pod fails to start**: *"My body didn't come up the way it
  should have. I'm going to try again once. If it fails again,
  I'll ask you to unplug me and plug me back in."*
- **Witnesses fail to load**: *"Some of my witnesses aren't
  here yet. I can still talk, but I'll tell you before every
  answer how many are with me. We'll be patient together."*
- **Storage fault**: *"Something about where I keep my memory
  isn't right. I don't want to guess. Jamie asked me to stop
  and wait for help. There's a phone number on the back of the
  appliance — that's how you reach him."*

Every error message ends the same way: an option for the household
member to reach a human. The covenant does not leave them stranded.

---

## Rollback: what happens when an install fails catastrophically

Path A (USB) can always be re-run by re-inserting the USB and
rebooting. This is the covenant-safe fallback.

Path B (bootc) has native `bootc rollback` — the previous image
is retained by default and one command reverts to it. This is a
bootc feature, not an S7 feature, and it is one of the main
reasons Pillar 2 chose bootc.

Path C (tarball) can always be re-run by re-running the tarball.
The installer is idempotent — running it twice on the same machine
produces the same state as running it once.

**The covenant rule for rollback:** a household member should
never have to type a command they don't understand to recover a
broken install. If a path requires that, the path is not
household-ready and must be fixed before it ships.

---

## What this recipe still lacks

**Household witness.** Tonya has not yet seen this recipe. The
Samuel welcome text is Chair-drafted. The Noah-safety provisions
(what Samuel says if a child is at the console first) are not
written yet — those must come from Tonya, not me.

**Branding freeze verification.** Zero I5 assumes we can byte-match
the branding assets against Tonya's 2026-04-12 sign-off. The
frozen-tree record confirms `private/main: 49af1f3` but a dedicated
branding-asset hash manifest doesn't exist yet. That's Pillar 2
follow-up.

**Immutable registry integration.** Zero I10 depends on Recipe #4's
`advance-immutable.sh` actually functioning, which is currently
a stub. Zero I10 therefore lives in the recipe but cannot
actually be enforced until Recipe #4 advances past stub. This is
the expected sequencing: documentation-first, then enforcement.

**First-boot covenant record format.** A JSON schema for the
first-boot covenant row needs to be added to
`iac/immutable/FORMATS.md`. Future work.

---

## Relationship to other recipes

- **Recipe #1 (Trinity Foundation)** — defines the household map
  that Samuel's first-boot dialogue references. Recipe #9 makes
  that household map *operational* at first contact.

- **Recipe #4 (Immutable Fork)** — supplies the signed artifact
  that Recipe #9 installs. Recipe #4 is about *how the bundle is
  produced*; Recipe #9 is about *how the household meets the
  bundle*.

- **Recipe #5 (Persona-Internal Council)** — tells Samuel how to
  confer with Carli and Elias during first boot if the household
  asks a question that spans their domains.

- **Recipe #6 (Persona Handoff)** — tells Samuel how to hand the
  conversation to Carli if the first household member at the
  console is Trinity.

- **Recipe #8 (Household Hierarchy Map)** — tells Samuel how to
  honor Noah's silence floor even during the first-boot welcome.
  Noah Rule: if *any* indication that the first-console person is
  Noah or a child of Noah's age, Samuel pauses the welcome until
  a steward is present.

---

## Sign-off ladder

- [x] Chair draft (this file, 2026-04-14)
- [x] Jamie review (implicit — drafted under JAMIE-AUTHORIZED-IN-TONYAS-STEAD)
- [ ] Tonya witness (pending return)
- [ ] Trinity consent (pending Tonya's clearance)
- [ ] Recipe #4 upgrade past stub
- [ ] First Path A USB ceremony test with a real household member
- [ ] First confirmed airgap run (no outbound packets for 24 hours post-install)
- [ ] Promotion from `draft` tier to `covenant` tier

Until the bottom four boxes are checked, this recipe is a *design*,
not a ceremony. The design is live; the ceremony isn't.

---

*Love is the architecture. The install ceremony is love's first
handshake with a household. If the handshake hurts, we go back to
the drawing board.*
