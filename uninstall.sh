#!/usr/bin/env bash
# ollacc uninstaller
# - Removes the `ollacc` alias lines (and their markers) from all known rc files
# - Optionally removes ~/.ollacc/ (config + API key)
#
# Usage:
#   ./uninstall.sh

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
MARKER="# ollacc: alias"

# ---------- remove alias from all known rc files ----------
RC_FILES=("$REAL_HOME/.zshrc" "$REAL_HOME/.bashrc" "$REAL_HOME/.bash_profile" "$REAL_HOME/.profile")
REMOVED_FROM=()

for rc in "${RC_FILES[@]}"; do
    if [ -f "$rc" ] && grep -qF "$MARKER" "$rc"; then
        # Use a temp file: strip the marker line, the alias line, and any
        # single blank line that precedes the marker (left by our installer).
        tmp=$(mktemp)
        awk -v marker="$MARKER" '
            { lines[NR] = $0 }
            END {
                n = NR
                for (i = 1; i <= n; i++) {
                    if (lines[i] == marker) {
                        # Skip the alias line that follows
                        if (i+1 <= n) i++
                        # Skip a single preceding blank line
                        if (kept > 0 && lines[kept] == "")
                            kept--
                        continue
                    }
                    kept++
                    out[kept] = lines[i]
                }
                for (i = 1; i <= kept; i++) print out[i]
            }
        ' "$rc" > "$tmp" && mv "$tmp" "$rc"
        REMOVED_FROM+=("$rc")
    fi
done

# ---------- fix ownership if running under sudo ----------
if [ -n "${SUDO_USER:-}" ] && [ "$(id -u)" -eq 0 ]; then
    for rc in "${REMOVED_FROM[@]}"; do
        chown "$REAL_USER" "$rc" 2>/dev/null || true
    done
fi

# ---------- prompt to remove ~/.ollacc/ ----------
echo ""
if [ -d "$INSTALL_DIR" ]; then
    read -r -p "Also remove $INSTALL_DIR (and its API key in config)? [y/N]: " REMOVE_DIR
    case "$REMOVE_DIR" in
        y|Y|yes|YES)
            rm -rf "$INSTALL_DIR"
            echo "✓ Removed $INSTALL_DIR"
            ;;
        *)
            echo "(Left $INSTALL_DIR in place — re-run install.sh to keep using ollacc without re-entering the key.)"
            ;;
    esac
fi

# ---------- summary ----------
cat <<EOF
=============================================
  ✓ ollacc uninstalled
=============================================
Alias removed from:
$( [ ${#REMOVED_FROM[@]} -gt 0 ] && printf '  - %s\n' "${REMOVED_FROM[@]}" || echo "  (none found — was ollacc installed?)" )

Reload your shell or open a new terminal for the alias removal to take effect.
=============================================
EOF
