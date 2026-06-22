#!/usr/bin/env bash
#
# Net-handler guard gate (ratchet) for the Windswept Colony schema.
#
# Fails if any raw net.Receive("LITERAL") site in this schema is not listed in
# tools/net-handlers.allowlist (next to this script). New client->server actions should go
# through the framework's ws.action.Register (the SWEP analogue is ws.weapon.NetReceive) —
# those wrappers take a variable netstring, so they never appear as net.Receive("LITERAL")
# and never trip this gate. A genuinely-correct raw net.Receive (server->client receiver,
# player-field session, two-phase token, ...) gets a conscious, reviewable line in the allowlist.
#
# Self-contained / single-repo (the framework runs the equivalent over its own tree; this is the
# schema's own copy so windswept-colony's CI doesn't need the private framework repo checked out).
# Portable: Git Bash (local) and the Ubuntu CI runner. Exit 0 = clean, 1 = unlisted handler(s),
# 2 = setup error.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../windswept-colony/tools
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"                          # .../windswept-colony
ALLOWLIST="$SCRIPT_DIR/net-handlers.allowlist"

if [ ! -f "$ALLOWLIST" ]; then
    echo "net-handler gate: missing allowlist at $ALLOWLIST" >&2
    exit 2
fi

# Allowed set: first whitespace-delimited token of each non-comment, non-blank line.
allowed="$(grep -vE '^[[:space:]]*(#|$)' "$ALLOWLIST" | awk '{print $1}' | sort -u)"

# Current set: every net.Receive("LITERAL") netstring in this schema (thirdparty excluded).
current="$(grep -rhoE 'net\.Receive\("[A-Za-z0-9_]+"' "$REPO" --include='*.lua' --exclude-dir=thirdparty 2>/dev/null \
    | sed -E 's/.*net\.Receive\("//; s/"$//' | sort -u)"

new="$(comm -23 <(printf '%s\n' "$current") <(printf '%s\n' "$allowed") | grep -vE '^$' || true)"
dead="$(comm -13 <(printf '%s\n' "$current") <(printf '%s\n' "$allowed") | grep -vE '^$' || true)"

status=0
if [ -n "$new" ]; then
    echo "net-handler gate: FAIL — raw net.Receive handler(s) not in tools/net-handlers.allowlist:" >&2
    printf '  %s\n' $new >&2
    echo "" >&2
    echo "Route client->server actions through ws.action.Register (SWEPs: ws.weapon.NetReceive)." >&2
    echo "If a raw net.Receive is genuinely correct as-is, add its netstring to tools/net-handlers.allowlist." >&2
    status=1
fi

if [ -n "$dead" ]; then
    echo "net-handler gate: note — allowlist entries no longer present (safe to prune):" >&2
    printf '  %s\n' $dead >&2
fi

if [ "$status" -eq 0 ]; then
    echo "net-handler gate: OK ($(printf '%s\n' "$current" | grep -cE '.') raw net.Receive sites, all allowlisted)"
fi
exit $status
