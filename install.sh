#!/usr/bin/env bash
# ollacc installer
# - Creates ~/.ollacc/ (chmod 700) and ~/.ollacc/config (chmod 600, with defaults)
# - Copies ollacc launcher into ~/.ollacc/ollacc (chmod 755)
# - Copies ollacc.conf.example into ~/.ollacc/ (reference)
# - Adds the `ollacc` alias to the user's first existing shell rc
#   (in order: zshrc, bashrc, bash_profile, profile); creates ~/.profile if none exist
# - Idempotent: safe to re-run; alias is only added once (marker-scoped)
#
# Usage:
#   ./install.sh
#   curl -sSL https://raw.githubusercontent.com/dansasser/ollacc/main/install.sh | bash

set -u

# ---------- determine real user / home (handle sudo) ----------
if [ -n "${SUDO_USER:-}" ]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
    REAL_USER="${USER:-$(id -un)}"
    REAL_HOME="${HOME:-$(eval echo "~$REAL_USER")}"
fi

INSTALL_DIR="$REAL_HOME/.ollacc"
LAUNCHER_SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/ollacc"
EXAMPLE_SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/ollacc.conf.example"

# ---------- preflight ----------
[ -f "$LAUNCHER_SRC" ] || {
    echo "ollacc installer: cannot find launcher at $LAUNCHER_SRC" >&2
    echo "Run this from the directory containing 'ollacc' (the repo root)." >&2
    exit 1
}

# ---------- create install dir ----------
mkdir -p "$INSTALL_DIR"
chmod 700 "$INSTALL_DIR"

# ---------- copy launcher ----------
install -m 755 "$LAUNCHER_SRC" "$INSTALL_DIR/ollacc"

# ---------- copy conf example (reference, not sourced) ----------
if [ -f "$EXAMPLE_SRC" ]; then
    install -m 644 "$EXAMPLE_SRC" "$INSTALL_DIR/ollacc.conf.example"
fi

# ---------- create config with defaults if missing ----------
if [ ! -f "$INSTALL_DIR/config" ]; then
    cat > "$INSTALL_DIR/config" <<'EOF'
# ollacc config — managed by the launcher. Edit directly if you prefer.
# The launcher will prompt for ANTHROPIC_AUTH_TOKEN on first run if empty.
ANTHROPIC_AUTH_TOKEN=""
ANTHROPIC_BASE_URL="https://ollama.com"
OLLAMA_CLAUDE_DEFAULT_MODEL=""
EOF
    chmod 600 "$INSTALL_DIR/config"
fi

# ---------- pick shell rc file ----------
RC_FILE=""
for candidate in .zshrc .bashrc .bash_profile .profile; do
    if [ -f "$REAL_HOME/$candidate" ]; then
        RC_FILE="$REAL_HOME/$candidate"
        break
    fi
done

if [ -z "$RC_FILE" ]; then
    # No rc files at all — create ~/.profile
    RC_FILE="$REAL_HOME/.profile"
    : > "$RC_FILE"
    chown "$REAL_USER" "$RC_FILE" 2>/dev/null || true
fi

# ---------- insert alias if not already present (idempotent) ----------
ALIAS_LINE="alias ollacc=\"$INSTALL_DIR/ollacc\""
MARKER="# ollacc: alias"
ADDED=0

if [ -f "$RC_FILE" ] && grep -qF "$ALIAS_LINE" "$RC_FILE"; then
    : # already present, no-op
else
    {
        echo ""
        echo "$MARKER"
        echo "$ALIAS_LINE"
    } >> "$RC_FILE"
    ADDED=1
fi

# ---------- fix ownership if running under sudo ----------
if [ -n "${SUDO_USER:-}" ] && [ "$(id -u)" -eq 0 ]; then
    chown -R "$REAL_USER" "$INSTALL_DIR" 2>/dev/null || true
    chown "$REAL_USER" "$RC_FILE" 2>/dev/null || true
fi

# ---------- summary ----------
cat <<EOF
=============================================
  ✓ ollacc installed
=============================================
  Install dir:  $INSTALL_DIR
  Config file:  $INSTALL_DIR/config  (chmod 600)
  Launcher:     $INSTALL_DIR/ollacc  (chmod 755)
  Alias added:  $RC_FILE  $( [ $ADDED -eq 1 ] && echo "(new)" || echo "(already present)" )

Next steps:
  1. Reload your shell, or open a new terminal:
       source $RC_FILE
  2. Run:
       ollacc
     It will prompt for your Ollama Cloud API key on first run.
=============================================
EOF
