# ═══════════════════════════════════════════════════════════════════
# S7 SkyCAIR — Sovereign Computing Platform
# UNIFIED LINUX SkyCAIR by S7 · 123Tech / 2XR, LLC
#
# Built on Fedora Server 44 Minimal
# One image. One install. Everything S7.
#
# Build:   podman build -t localhost/s7-skycair:v6-genesis .
# Run:     podman run -it localhost/s7-skycair:v6-genesis
# Install: bootc install localhost/s7-skycair:v6-genesis
#
# SOVEREIGN BUILD RULE (feedback_no_ghcr.md): no ghcr.io, no
# Docker Hub at build time. The image lives in the local podman
# store and is distributed as an oci-archive tarball or via the
# immutable-S7-F44 GitHub repository after signing.
#
# Love is the architecture.
# ═══════════════════════════════════════════════════════════════════
FROM quay.io/fedora/fedora-bootc:44

LABEL maintainer="Jamie Lee Clayton <jamie@2xr.llc>"
LABEL org.opencontainers.image.title="S7 SkyCAIR"
LABEL org.opencontainers.image.description="Sovereign Computing Platform — AI + Humanity, Built on Trust"
LABEL org.opencontainers.image.vendor="2XR LLC / 123Tech"
LABEL org.opencontainers.image.licenses="Apache-2.0 AND BSL-1.1"
LABEL org.opencontainers.image.source="https://github.com/skycair-code/SkyQUBi-public"

# ── Layer 1: Desktop + System Groups ─────────────────────────────
# Mirrors: Fedora Server 44 Minimal → Budgie desktop + container management
# NOTE: Fedora 44's dnf5 requires group IDs (lowercase-hyphenated),
# not display names. Use `dnf group list` in fedora:44 to see the ID column.
RUN dnf group install -y \
      budgie-desktop \
      container-management \
      headless-management \
      domain-client && \
    dnf clean all

# ── Layer 2: S7 System Packages ──────────────────────────────────
# Display manager, reverse proxy, terminals, dev tools, media.
#
# BUG FIX 2026-04-15 SOLO: inline # comments inside a backslash-
# continued dnf install arg list become literal package names —
# bash does not treat them as comments mid-list. The previous
# version had 9 such inline comments that would have broken the
# build on first attempt. All comments are now outside the dnf
# arg list.
#
# Groups covered (no inline breaks):
#   Display + desktop:  sddm, lightdm, gtklock, plymouth themes,
#                       dconf-editor, gnome tweaks/editor/software,
#                       thunar plugins, wdisplays, xdg portals,
#                       xdg user dirs, conky
#   Networking:         network-manager-applet, dnsmasq
#   Terminals:          kitty
#   Server + tools:     caddy, git, ripgrep, ImageMagick,
#                       libreoffice-calc, sassc, glib2-devel,
#                       gtk2-engines, gtk-murrine-engine
#   VFS + filesystems:  gvfs-fuse, gvfs-mtp, gvfs-smb
#   Package mgmt:       PackageKit, fedora-flathub-remote,
#                       fedora-workstation-repositories
#   Python:             python3-pip, python3-psycopg2, python3-flask
#
# COVENANT FIX 2026-04-15 SOLO: nodejs24-npm REMOVED per the
# No-NPM-at-runtime covenant rule (feedback_never_embed_secrets...
# + B5 install.sh cleanup). If a future component truly needs
# Node.js, ship it as a pre-built artifact, not a runtime dep.
RUN dnf install -y \
      sddm-wayland-miriway \
      lightdm-gtk \
      gtklock \
      plymouth-theme-script \
      plymouth-plugin-script \
      dconf-editor \
      gnome-tweaks \
      gnome-text-editor \
      gnome-software \
      gnome-color-manager \
      thunar-archive-plugin \
      thunar-volman \
      wdisplays \
      xdg-desktop-portal \
      xdg-desktop-portal-gtk \
      xdg-desktop-portal-wlr \
      xdg-user-dirs-gtk \
      conky \
      network-manager-applet \
      dnsmasq \
      kitty \
      caddy \
      git \
      ripgrep \
      ImageMagick \
      libreoffice-calc \
      sassc \
      glib2-devel \
      gtk2-engines \
      gtk-murrine-engine \
      gvfs-fuse \
      gvfs-mtp \
      gvfs-smb \
      PackageKit \
      fedora-flathub-remote \
      fedora-workstation-repositories \
      python3-pip \
      python3-psycopg2 \
      python3-flask && \
    dnf clean all

# ── Layer 3: Python Dependencies (CWS Engine + S7 Stack) ─────────
# BUG FIX 2026-04-15 SOLO: same inline-comment bug as Layer 2.
# Removed the inline `# CWS Engine core`, `# S7 stack`, `# Utilities`
# comments that would have been passed to pip as literal package
# specs, breaking the build.
#
# Groups covered (comments ABOVE the RUN, not inside it):
#   CWS Engine core: fastapi, uvicorn, httpx, pydantic,
#                    pydantic-settings, psycopg2-binary, python-dotenv
#   S7 stack:        chromadb, mempalace, onnxruntime, orjson,
#                    huggingface_hub, tokenizers, numpy
#   Utilities:       weasyprint, python-docx, kubernetes, yt-dlp,
#                    typer, rich, pytest
RUN pip install --no-cache-dir \
      fastapi==0.135.3 \
      uvicorn==0.44.0 \
      httpx==0.28.1 \
      pydantic==2.12.5 \
      pydantic-settings==2.13.1 \
      psycopg2-binary==2.9.11 \
      python-dotenv==1.2.2 \
      chromadb==1.5.7 \
      mempalace==3.0.0 \
      onnxruntime==1.24.4 \
      orjson==3.11.8 \
      huggingface_hub==1.9.2 \
      tokenizers==0.22.2 \
      numpy==2.4.4 \
      weasyprint==68.1 \
      python-docx==1.2.0 \
      kubernetes==35.0.0 \
      yt-dlp==2026.3.17 \
      typer==0.24.1 \
      rich==14.3.3 \
      pytest==9.0.3

# ── Layer 4: Ollama ──────────────────────────────────────────────
#
# COVENANT FIX 2026-04-15 SOLO: the original line was
#     RUN curl -fsSL https://ollama.com/install.sh | sh
# which is both an outbound network call at build time AND a
# pipe-to-shell install from an external URL. Reviewer #3 of the
# Opus review synthesis flagged this as BLOCKER 3. Covenant says:
# the bootc image must be buildable offline from vendored
# artifacts.
#
# INTERIM SOLUTION (pre-v6-genesis-ship): Ollama is NOT installed
# in the bootc image at all. It is installed at first-boot via
# the install/first-boot.sh script from a vendored tarball in
# /s7/Local-Private-Assets/. This keeps the bootc image pure and
# moves the external dependency to a known first-boot step that
# can be audited separately.
#
# PERMANENT SOLUTION (post-v6-genesis): the Ollama binary is
# downloaded once, sha256-verified, committed to the immutable-
# S7-F44 repository as a vendored artifact, and COPY'd into the
# image here. Tracked as a Pillar 1 airgap gap.
#
# NOTHING IS RUN AT THIS LAYER until the vendored path is ready.
# This preserves the offline-buildable property of the image.

# ── Layer 5: S7 OS Customization ─────────────────────────────────
# os-release branding
COPY os/os-release /usr/lib/os-release.d/s7
COPY os/issue /etc/issue.d/s7.issue

# Plymouth theme
COPY branding/plymouth/ /usr/share/plymouth/themes/s7/

# Wallpapers + icons
COPY branding/wallpapers/ /usr/share/backgrounds/s7/
COPY branding/icons/ /usr/share/icons/s7/
COPY branding/splash/ /usr/share/s7/splash/

# SDDM theme
COPY branding/sddm/ /usr/share/sddm/themes/s7/

# GRUB theme
COPY branding/grub/ /usr/share/s7/grub/

# ── Layer 6: SkyQUBi AI Stack ────────────────────────────────────
# CWS Engine
COPY engine/ /opt/s7/engine/

# Pod manifest (template — secrets injected at runtime)
COPY skyqubi-pod.yaml /opt/s7/skyqubi-pod.yaml

# Caddy reverse proxy config
COPY services/Caddyfile /opt/s7/Caddyfile

# ── Layer 7: Systemd Services ────────────────────────────────────
COPY services/s7-cws-engine.service  /usr/lib/systemd/user/
COPY services/s7-caddy.service       /usr/lib/systemd/user/
COPY services/s7-ollama.service      /usr/lib/systemd/user/
COPY services/s7-skyqubi-pod.service /usr/lib/systemd/user/
COPY services/s7-bitnet-mcp.service  /usr/lib/systemd/user/
COPY services/s7-dashboard.service   /usr/lib/systemd/user/

# Desktop autostart
COPY autostart/ /etc/xdg/autostart/

# Desktop entries
COPY desktop/ /usr/share/applications/

# ── Layer 8: Install Script + Secrets Template ───────────────────
COPY install/install.sh /opt/s7/install.sh
COPY .env.example       /opt/s7/.env.example
COPY install/first-boot.sh /opt/s7/first-boot.sh
RUN chmod +x /opt/s7/install.sh /opt/s7/first-boot.sh

# ── Layer 9: S7 os-release override ─────────────────────────────
RUN echo 'NAME="S7"' > /etc/os-release && \
    echo 'PRETTY_NAME="S7 SkyCAIR — Sovereign Computing Platform"' >> /etc/os-release && \
    echo 'ID=s7' >> /etc/os-release && \
    echo 'ID_LIKE=fedora' >> /etc/os-release && \
    echo 'VERSION="2.0.0"' >> /etc/os-release && \
    echo 'VERSION_ID=2' >> /etc/os-release && \
    echo 'VARIANT="SkyQUBi"' >> /etc/os-release && \
    echo 'VARIANT_ID=skyqubi' >> /etc/os-release && \
    echo 'HOME_URL="https://skycair.com"' >> /etc/os-release && \
    echo 'BUG_REPORT_URL="https://github.com/skycair-code/SkyCAIR/issues"' >> /etc/os-release

# Civilian use only
LABEL org.skycair.civilian-only="true"
