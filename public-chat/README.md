# S7 SkyQUBi — Public Chat Service

Standalone, minimal chat microservice for the public website.
**Completely separate from the CWS Engine stack.**

## What This Is

A thin HTTP proxy between Jamie's laptop's local Ollama and the public web.

- Port **57088** (in the S7 range)
- Bound to **127.0.0.1** by default (no public exposure without tunnel)
- Talks **only** to Ollama on `127.0.0.1:57081`
- Uses model `qwen2.5:3b` (1.9GB, runs locally)
- No persistence, no logging, no stack dependencies

## What This Is NOT

- **Not** the CWS Engine
- **Not** connected to MemPalace, molecular bonds, or the witness system
- **Not** "Carli" — it's a public demo with the `qwen2.5:3b` model
- **Not** logged — visitor conversations leave no trace after the response

## Architecture

```
Web visitor
  → skyqubi.com / skyqubi.ai (Wix site)
  → HTML embed (iframe or widget)
  → Cloudflare Tunnel / ngrok → https://chat.skyqubi.ai
  → Laptop port 57088 (public-chat service)
  → Laptop port 57081 (Ollama)
  → Model (qwen2.5:3b)
  → Response back
```

**The laptop is the only place the AI runs.** The tunnel just gives the web a
secure door into the laptop. No conversations are stored anywhere.

## Run It

```bash
# Install dependencies (first time)
pip install --user fastapi uvicorn httpx pydantic

# Run
python3 /s7/skyqubi-private/public-chat/app.py
```

Or install as a systemd user service (see `public-chat.service`).

## Expose To The Web

You need a tunnel because the laptop is behind NAT. Options:

### Option A — Cloudflare Tunnel (recommended)
Free, no rate limits, HTTPS automatic, stable subdomain.

```bash
# Install cloudflared (one time)
sudo dnf install cloudflared

# Login to Cloudflare (opens browser)
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create s7-public-chat

# Configure it to forward to localhost:57088
# (see cloudflared config doc for YAML)

# Run the tunnel
cloudflared tunnel run s7-public-chat
```

Point `chat.skyqubi.ai` at the tunnel via a CNAME.

### Option B — ngrok (fastest to set up)
Free tier with random URLs, paid for stable subdomains.

```bash
ngrok http 57088
```

Use the generated URL in your Wix embed.

## Embed On Wix

The service provides a ready-made widget at `/widget`. Embed it on Wix with
an HTML iframe block:

```html
<iframe
  src="https://chat.skyqubi.ai/widget"
  style="width:100%;height:600px;border:none;border-radius:12px;"
></iframe>
```

Or paste the widget HTML directly into a Wix HTML Embed element.

## Rate Limits

- **10 messages per minute** per IP
- **60 messages per hour** per IP
- Responses capped at **300 tokens**
- Message length capped at **500 characters**

These prevent overload on the laptop. For heavy traffic, visitors are
encouraged to download SkyQUBi and run it themselves.

## Security

- CORS restricted to skyqubi.com, skyqubi.ai, and their subdomains
- No authentication (public demo)
- No persistent storage
- No logging of message content
- Bound to localhost — only the tunnel reaches it
- Separate process from the CWS stack — can be killed without affecting the pod

## Honest Framing

This is a **demo**, not the full platform. The real SkyQUBi includes:
- CWS Engine with circuit breaker
- Molecular bond memory
- 3-agent consensus voting
- SkyAVi system skills

Visitors who want the real thing download the public repo and run it on
their own hardware. That is the point of SkyQUBi: it is meant to live on
your machine, not someone else's.

## License

CWS-BSL-1.1 — Civilian use only.

*Love is the architecture.*
