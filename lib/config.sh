# lib/config.sh — config I/O for ~/.ollacc/config
# Sourced by ollacc. Defines path vars and three helpers.
# All functions assume $OLLACC_HOME and $OLLACC_CONFIG are set.

# ollacc: <msg> — print to stderr and exit 1
die() { echo "ollacc: $*" >&2; exit 1; }

# config_set <key> <value> — write or replace a single KEY="value" assignment
# in $OLLACC_CONFIG while preserving comments and unrelated lines.
config_set() {
    local key="$1" value="$2"
    mkdir -p "$OLLACC_HOME"
    touch "$OLLACC_CONFIG"
    chmod 600 "$OLLACC_CONFIG"
    if grep -qE "^[[:space:]]*${key}=" "$OLLACC_CONFIG"; then
        # Replace existing line
        local tmp
        tmp=$(mktemp)
        awk -v k="$key" -v v="$value" '
            BEGIN { done = 0 }
            /^[[:space:]]*#/ { print; next }
            {
                if (!done && $0 ~ "^[[:space:]]*" k "=") {
                    print k "=\"" v "\""
                    done = 1
                } else {
                    print
                }
            }
            END { if (!done) print k "=\"" v "\"" }
        ' "$OLLACC_CONFIG" > "$tmp" && mv "$tmp" "$OLLACC_CONFIG"
    else
        printf '%s="%s"\n' "$key" "$value" >> "$OLLACC_CONFIG"
    fi
    chmod 600 "$OLLACC_CONFIG"
}

# config_unset <key> — remove the line for KEY=... from $OLLACC_CONFIG
# (no-op if the file doesn't exist). Comments preserved.
config_unset() {
    local key="$1"
    [ -f "$OLLACC_CONFIG" ] || return 0
    local tmp
    tmp=$(mktemp)
    awk -v k="$key" '
        /^[[:space:]]*#/ { print; next }
        $0 ~ "^[[:space:]]*" k "=" { next }
        { print }
    ' "$OLLACC_CONFIG" > "$tmp" && mv "$tmp" "$OLLACC_CONFIG"
    chmod 600 "$OLLACC_CONFIG"
}
