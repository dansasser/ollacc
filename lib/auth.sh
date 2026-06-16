# lib/auth.sh — load config, prompt for API key on first run.
# Sets $ANTHROPIC_AUTH_TOKEN in the current shell on return.
# Assumes $OLLACC_CONFIG, $OLLACC_HOME, and config_set / die are available.

# auth_load_config — source ~/.ollacc/config if it exists.
# No-op if missing. Sets default $ANTHROPIC_BASE_URL if unset.
auth_load_config() {
    if [ -f "$OLLACC_CONFIG" ]; then
        # shellcheck disable=SC1090
        . "$OLLACC_CONFIG"
    fi
    : "${ANTHROPIC_BASE_URL:=https://ollama.com}"
}

# auth_prompt_if_missing — if $ANTHROPIC_AUTH_TOKEN is empty, show the
# no-key splash, read a key silently, save to config, show confirmation.
# Always sets $ANTHROPIC_AUTH_TOKEN in the current shell on return.
auth_prompt_if_missing() {
    if [ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
        return 0
    fi

    cat <<'EOF'
=============================================
  🔑 Ollama Cloud API Key Required
=============================================
ollacc needs an Ollama Cloud API key to connect.

How to get one:
  1. Open https://ollama.com/settings/keys in your browser
  2. Click "Generate API Key"
  3. Copy the key

You can either:
  (a) Paste it at the prompt below, OR
  (b) Edit the config file directly:
      ~/.ollacc/config
      (set ANTHROPIC_AUTH_TOKEN="<your-key>")

The key is stored with chmod 600 (only you can read it).
=============================================
EOF
    read -r -s -p "Paste key (input is hidden): " NEW_KEY
    echo
    if [ -z "$NEW_KEY" ]; then
        die "No key provided. Aborting."
    fi
    config_set ANTHROPIC_AUTH_TOKEN "$NEW_KEY"
    ANTHROPIC_AUTH_TOKEN="$NEW_KEY"
    cat <<'EOF'
=============================================
  ✓ Key saved to ~/.ollacc/config
=============================================
Continuing to model selection…
=============================================
EOF
}

# auth_export_sdk_env — export the three env vars the Anthropic SDK needs.
# Per Ollama issue #13854, ANTHROPIC_API_KEY must be empty.
auth_export_sdk_env() {
    export ANTHROPIC_BASE_URL
    export ANTHROPIC_AUTH_TOKEN
    export ANTHROPIC_API_KEY=""
}
