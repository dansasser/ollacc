# lib/config.sh — config I/O and string-escape helpers for ~/.ollacc/config
# Sourced by ollacc. All functions assume $OLLACC_HOME and $OLLACC_CONFIG are set.

# ollacc: <msg> — print to stderr and exit 1
die() { echo "ollacc: $*" >&2; exit 1; }

# bash_escape <string> — emit <string> in a form that is safe to place inside
# double quotes in bash source (whether for parsing OR for use as a glob pattern).
# Escapes \, $, `, ", and the glob metacharacters *, ?, [, ].
# Use as:  foo="bar$(bash_escape "$value")baz"
#
# Implementation note: a single char class like `[\\$`"*?\[\]]` looks cleaner
# but is NOT portable — GNU sed parses `*?` inside `[...]` as a range
# (42-63), which silently drops the `"` (34) from the class. We use one
# expression per character instead.
bash_escape() {
    printf '%s' "$1" | sed \
        -e 's/\\/\\\\/g' \
        -e 's/\$/\\$/g' \
        -e 's/`/\\`/g' \
        -e 's/"/\\"/g' \
        -e 's/\*/\\*/g' \
        -e 's/?/\\?/g' \
        -e 's/\[/\\[/g' \
        -e 's/\]/\\]/g'
}

# config_set <key> <value> — write or replace a single KEY="value" assignment
# in $OLLACC_CONFIG while preserving comments and unrelated lines.
# The value is escaped so that double-quote, dollar, backtick, and backslash
# characters in the input cannot break out of the quoted assignment when the
# config is later `.`-sourced.
config_set() {
    local key="$1" value="$2" esc_value
    esc_value=$(bash_escape "$value")
    mkdir -p "$OLLACC_HOME"
    touch "$OLLACC_CONFIG"
    chmod 600 "$OLLACC_CONFIG"
    if grep -qE "^[[:space:]]*${key}=" "$OLLACC_CONFIG"; then
        # Replace existing line
        local tmp
        tmp=$(mktemp)
        awk -v k="$key" -v v="$esc_value" '
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
        printf '%s="%s"\n' "$key" "$esc_value" >> "$OLLACC_CONFIG"
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
