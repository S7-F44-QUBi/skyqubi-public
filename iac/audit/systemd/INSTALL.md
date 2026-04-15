# S7 Living Audit — systemd user units

These two files install the nightly snapshot loop for the Living
Audit Document. They are user units (no root needed) and run as the
`s7` user.

## What they do

- **`s7-living-snapshot.timer`** fires once a night at 03:00 local
  (America/Chicago). `Persistent=true` catches up after a reboot.
- **`s7-living-snapshot.service`** runs (a) the pre-sync gate to
  refresh `docs/internal/chef/audit-living.md`, then (b) the
  insert-only `nightly-snapshot.sh` to copy the day's Living
  Document into `docs/internal/chef/audit-living/<date>.md`.

The first ExecStart has a leading `-` so the snapshot still runs
even if the gate finds warnings — we want the witness trail to
capture warning days, not skip them.

## Install

```
cp s7-living-snapshot.service ~/.config/systemd/user/
cp s7-living-snapshot.timer   ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now s7-living-snapshot.timer
systemctl --user list-timers s7-living-snapshot.timer
```

## Verify

```
systemctl --user status s7-living-snapshot.service
journalctl --user -u s7-living-snapshot.service -n 30
ls /s7/skyqubi-private/docs/internal/chef/audit-living/
```

## Uninstall

```
systemctl --user disable --now s7-living-snapshot.timer
rm ~/.config/systemd/user/s7-living-snapshot.{service,timer}
systemctl --user daemon-reload
```

## Why systemd user units (not system cron)

- No root needed. Civilian appliance posture.
- Runs only when the `s7` user is logged in / lingering, which is
  the household's intended state.
- Reversible in three commands.
- The future Samuel-heartbeat skill (Phase 4 of the Jamie Love RCA
  plan) will eventually replace this — at which point we just
  disable the timer and Samuel takes over. The Living Document
  itself doesn't change.
