# lib/catalog.sh — resolve the model list to show the user.
# Produces a global array MAPFILE (top 10 model names) and the global
# $authd_json (raw response from /api/tags). Caller must have
# $ANTHROPIC_AUTH_TOKEN set and exported before calling.
#
# Sources lib/config.sh for bash_escape (catalog-loop membership check
# must treat the candidate as a literal substring, not a glob).

# shellcheck source=lib/config.sh
. "${BASH_SOURCE%/*}/config.sh"

# authd_json — raw response from https://ollama.com/api/tags (auth'd).
# Populated by catalog_resolve.
authd_json=""

# MAPFILE — array of model slugs to show, in display order.
# Populated by catalog_resolve.
declare -a MAPFILE=()

# catalog_resolve — fetch the auth'd catalog, scrape the popular ordering,
# intersect them, fall back to auth'd-catalog order, then to a hardcoded
# last-resort list. Sets the globals $authd_json and MAPFILE.
catalog_resolve() {
    # Always start clean — the function may be called more than once per run
    # (e.g. after a future --refresh-catalog or --model-clear flow).
    MAPFILE=()
    authd_json=""

    # 1. Auth'd catalog (Bearer token)
    # -sf: silent + fail-on-HTTP-error (so 4xx/5xx become empty body, not error text
    #       concatenated to the body that we'd then try to JSON-grep).
    # --max-time/--connect-timeout: bound the wait so a hung ollama.com doesn't
    #       stall the launcher; on timeout we fall through to the last-resort list.
    if ! authd_json=$(curl -sf --max-time 10 --connect-timeout 5 \
            -H "Authorization: Bearer $ANTHROPIC_AUTH_TOKEN" \
            "https://ollama.com/api/tags"); then
        authd_json=""
    fi

    # 2. Popular-order scrape
    local scrape_html
    if ! scrape_html=$(curl -sf --max-time 10 --connect-timeout 5 \
            "https://ollama.com/search?c=cloud"); then
        scrape_html=""
    fi

    # 3. Intersect: keep popular-order slugs that exist in the auth'd catalog.
    # The candidate may contain glob metacharacters (e.g. a model named "foo*");
    # build a glob-safe needle and use grep -F for a literal substring check
    # rather than the [[ == *"$x"* ]] pattern (which is globby on the outer *'s
    # even when $x is quoted).
    local remaining_scrape="$scrape_html"
    while [[ "$remaining_scrape" =~ href=\"/library/([^\"/]+)\" ]]; do
        local candidate="${BASH_REMATCH[1]}"
        if [[ ! " ${MAPFILE[*]} " =~ " ${candidate} " ]] \
           && printf '%s' "$authd_json" | grep -qF "\"name\":\"$candidate\""; then
            MAPFILE+=("$candidate")
        fi
        remaining_scrape="${remaining_scrape#*href=\"/library/}"
        [ ${#MAPFILE[@]} -eq 10 ] && break
    done

    # 4. Fallback: if scraping produced nothing, use auth'd catalog order
    if [ ${#MAPFILE[@]} -eq 0 ]; then
        echo "⚠️ Could not fetch popular ordering; using auth'd catalog order."
        local remaining_json="$authd_json"
        while [[ "$remaining_json" =~ \"name\":\"([^\"]+)\" ]]; do
            local m="${BASH_REMATCH[1]}"
            if [[ ! " ${MAPFILE[*]} " =~ " ${m} " ]]; then
                MAPFILE+=("$m")
            fi
            remaining_json="${remaining_json#*\"name\"}"
            [ ${#MAPFILE[@]} -eq 10 ] && break
        done
    fi

    # 5. Last-resort: hardcoded list when both networks fail
    if [ ${#MAPFILE[@]} -eq 0 ]; then
        echo "⚠️ Could not reach ollama.com at all. Using last-known defaults."
        MAPFILE=("kimi-k2.7-code" "minimax-m3" "qwen3.5" "glm-5.1" "minimax-m2.7")
    fi
}
