# lib/menu.sh — render the model menu, read+validate the choice,
# offer to save the chosen model as the new default.
# Assumes global MAPFILE is populated and config_set is available.

# menu_render — print the numbered model list + [Custom] option.
menu_render() {
    clear
    echo "============================================="
    echo "   🤖 ollacc - Ollama Cloud Claude Code     "
    echo "============================================="
    echo "Select a cloud model to run:"
    echo "---------------------------------------------"

    local i
    for i in "${!MAPFILE[@]}"; do
        printf "%2d) %s\n" "$((i+1))" "${MAPFILE[$i]}"
    done

    local custom_index=$(( ${#MAPFILE[@]} + 1 ))
    printf "%2d) [Custom] Enter your own model name\n" "$custom_index"
    echo "============================================="
}

# menu_choose — read the user's choice, validate, return the chosen model
# slug via the global $MODEL variable.
menu_choose() {
    local custom_index=$(( ${#MAPFILE[@]} + 1 ))
    local choice
    read -r -p "Enter choice (1-$custom_index): " choice

    # Validate as integer FIRST so non-numeric input (e.g. "c") doesn't get
    # evaluated as a variable name inside `[[ ... -ge ... ]]` under `set -u`.
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        if [[ "$choice" -ge 1 && "$choice" -le "${#MAPFILE[@]}" ]]; then
            MODEL="${MAPFILE[$((choice-1))]}"
        elif [[ "$choice" -eq "$custom_index" ]]; then
            echo ""
            local custom_model
            read -r -p "➡️ Enter custom model name: " custom_model
            MODEL="${custom_model:-minimax-m3}"
        else
            echo "❌ Invalid choice. Defaulting to first available model."
            MODEL="${MAPFILE[0]}"
        fi
    else
        echo "❌ Invalid choice. Defaulting to first available model."
        MODEL="${MAPFILE[0]}"
    fi
}

# menu_offer_save_default — if $MODEL differs from the current default,
# ask the user if they want to save it. Persists to config on yes.
menu_offer_save_default() {
    # Skip the prompt if the user picked the existing default
    if [ "$MODEL" = "${OLLAMA_CLAUDE_DEFAULT_MODEL:-}" ]; then
        return 0
    fi

    local save_default
    read -r -p "💾 Make \"$MODEL\" your default model? [y/N]: " save_default
    case "$save_default" in
        y|Y|yes|YES)
            config_set OLLAMA_CLAUDE_DEFAULT_MODEL "$MODEL"
            echo "✓ Default set to: $MODEL"
            ;;
        *)
            echo "(Not saved as default)"
            ;;
    esac
}
