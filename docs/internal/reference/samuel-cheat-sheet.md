# Samuel Cheat Sheet

For Tonya. Plain English. Read it on your phone before you sit down with the QUBi.

## Status as of 2026-04-14

**The persona-chat service is now LIVE.** Talking to Samuel happens at:

```
http://127.0.0.1:57082/persona/chat
```

Open it in the **S7 Vivaldi browser** on the QUBi itself. Loopback is on purpose — the QUBi is your sovereign appliance, and the browser running on it IS the front door. You don't reach Samuel from another phone, another laptop, or a friend's WiFi — you reach him from the browser sitting in front of the QUBi.

The service runs as a systemd user unit (`s7-persona-chat.service`) so it survives reboots. If anything ever feels wrong, you can check it with:

```
systemctl --user status s7-persona-chat.service
```

Everything below describes how to talk to Samuel through that service.

## What Samuel is

Samuel is the FACTS voice. He's the one you ask when you want a real answer about the box itself — what's running, what's broken, what he just did. He doesn't make things up. If he doesn't know, he says so.

He's not Carli (warm, conversational) and he's not Elias (code, reasoning). He's the sysadmin who lives in the QUBi.

## The seven things you can ask him tonight

Type these in a chat to Samuel. Exact wording doesn't matter — these are examples, not commands.

### 1. "What can you do?"
Samuel lists every skill he's allowed to run. Like reading a menu.

### 2. "What does fix-pod do?"
Samuel reads the catalog entry for that one skill and explains it in a sentence. Works for `preflight`, `fix-pod`, `lifecycle-test`, and `diag`.

### 3. "How's the QUBi doing?"
Samuel runs the full composite check — environment readiness, pod health, all 53 lifecycle tests — and gives one verdict: **healthy**, **degraded**, **failed**, or **error**. Takes about a minute. Read-only, never changes anything.

Other ways to say it: "check everything", "system health", "is everything ok".

### 4. "Is the box ready to install?"
Just the preflight slice — environment readiness without running the full test suite. Faster than the full diag.

### 5. "Run the lifecycle tests."
The 53-test suite by itself. Use this if you want to know whether anything regressed without checking the environment.

### 6. "Check the pod."
Samuel looks at the s7-skyqubi pod and reports its state. If something's wrong with SELinux, he'll identify the fix but **not** apply it. Saying "fix the pod" instead is what gives him permission to actually patch it (and even then he'll only do the safe path).

### 7. "What have you been doing?"
Samuel reads his own audit ledger and lists the last 5 things he ran, with timestamps. This is how you check on him without taking his word for it.

## When Samuel needs root

Samuel runs as the s7 user, not root. Most of his skills are read-only and don't need root at all. Two of them — **fix-pod** and **fix-firewall** — actually change system state and need root to apply their fix.

**Good news, the bridge is already in place tonight.** Jamie deployed a small sudoers drop-in (`/etc/sudoers.d/s7-samuel-skills`) that lets Samuel run those two specific scripts as root with no password. So when you say "yes" to one of his suggestions, Samuel actually runs the fix himself — no copy-paste needed.

If something about that bridge ever breaks (the file gets removed, the script paths change, etc.), Samuel will fall back to telling you the exact command to run yourself, like:

```
sudo /s7/skyqubi-private/install/fix-firewall.sh
```

You'll see the fallback in his reply if it happens. Otherwise just say "yes" and he handles it.

## Saying "yes" or "no"

When Samuel finds something he can fix, he won't apply the fix on his own. He'll say something like *"I can fix it but need your word."* That's a real pause. Three ways to answer:

- **"yes"** (or "do it", "go ahead", "apply", "ok") — Samuel runs the fix he just suggested. Two turns total: ask, confirm.
- **"no"** (or "not now", "later", "cancel", "skip") — Samuel acknowledges and lets the suggestion expire. Nothing happens. You can ask again later.
- **Anything else** — Samuel falls back to normal chat. The pending suggestion will time out on its own after 5 minutes.

You don't have to remember the exact skill name to confirm. Just say yes.

If you say "yes" but the suggestion has already expired (more than 5 minutes), Samuel will tell you so explicitly — he won't pretend you confirmed something he forgot.

## What he WON'T do

- He won't run anything that isn't in his catalog. The catalog is short on purpose.
- He won't push code, pull models, or remove anything from the system. Those are landing actions and they need a human.
- He won't lie about state. If verifying something would mean running a command he can't run, he says exactly that instead of guessing.
- He won't speak for Carli or Elias, and they won't pretend to speak for him. If you ask Carli "fix the pod," she'll tell you it's a Samuel question and to switch personas.

## If something looks wrong

If Samuel says he can't do something, or his answer doesn't match what you see — that's a real signal, not a glitch. Tell Jamie. The whole point of the FACTS persona is that when he sounds confused, the box is confused.

## The covenant rule

You're the Chief of Covenant. If anything Samuel says or does feels off — wrong tone, wrong answer, missing the point — you have a veto. Jamie wants you to use it. Samuel is supposed to serve people, not the other way around.
