# lib/flags.sh — handle management flags before any other work.
# Handle these BEFORE sourcing config / asking for the key, so the user can
# always reset state regardless of where they are in the flow.
# Exits 0 on either flag. Returns 1 (via fallthrough) if no flag matched,
# letting the orchestrator continue to normal flow.

# flags_handle <argv1> — process --model-clear / --key-clear.
# Returns 0 if a flag was handled (and exited), 1 if not.
flags_handle() {
    case "${1:-}" in
        --model-clear)
            if [ -f "$OLLACC_CONFIG" ]; then
                config_unset OLLAMA_CLAUDE_DEFAULT_MODEL
                echo "✓ Default model cleared. Next run will show the model menu."
            else
                echo "✓ No config exists; nothing to clear."
            fi
            exit 0
            ;;
        --key-clear)
            if [ -f "$OLLACC_CONFIG" ]; then
                config_unset ANTHROPIC_AUTH_TOKEN
                echo "✓ API key cleared. Next run will prompt for a new key."
            else
                echo "✓ No config exists; nothing to clear."
            fi
            exit 0
            ;;
    esac
    return 1
}
