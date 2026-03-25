#!/usr/bin/env bash
# health_check.sh — Verify control-plane sync is healthy
#
# Checks:
# 1. ~/.stack/infra/ exists and is accessible
# 2. Last sync was within the last 15 minutes (cloned servers only)
# 3. CLAUDE.md symlink is valid
# 4. Registry files exist
#
# Usage:
#   bash health_check.sh           # run all checks
#   bash health_check.sh --quiet   # exit code only (0=healthy, 1=unhealthy)

set -uo pipefail

INFRA_DIR="$HOME/.stack/infra"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
QUIET=false

[[ "${1:-}" == "--quiet" ]] && QUIET=true

PASS=0
FAIL=0

check() {
    local label="$1"
    shift
    if "$@" > /dev/null 2>&1; then
        $QUIET || echo "  [PASS] $label"
        PASS=$((PASS + 1))
    else
        $QUIET || echo "  [FAIL] $label"
        FAIL=$((FAIL + 1))
    fi
}

$QUIET || echo "Control-plane health check:"

# Core checks
check "~/.stack/infra/ exists" test -d "$INFRA_DIR"
# For symlinks, verify the target is also accessible
if [[ -L "$INFRA_DIR" ]]; then
    check "Symlink target is valid" test -d "$INFRA_DIR/registry"
else
    check "Is a git repo" test -d "$INFRA_DIR/.git"
fi
check "registry/servers.yaml exists" test -f "$INFRA_DIR/registry/servers.yaml"
check "registry/apps.yaml exists" test -f "$INFRA_DIR/registry/apps.yaml"
check "registry/repos.yaml exists" test -f "$INFRA_DIR/registry/repos.yaml"
check "infra.md exists" test -f "$INFRA_DIR/infra.md"
check "CLAUDE.md has stack injection" grep -q "STACK_INJECT_START" "$CLAUDE_MD"

# Sync freshness (only for real clones, not symlinks)
if [[ -d "$INFRA_DIR/.git" && ! -L "$INFRA_DIR" ]]; then
    LAST_FETCH="$INFRA_DIR/.git/FETCH_HEAD"
    if [[ -f "$LAST_FETCH" ]]; then
        # Cross-platform stat: try GNU stat first, then BSD stat
        FETCH_MTIME=$(stat -c %Y "$LAST_FETCH" 2>/dev/null || stat -f %m "$LAST_FETCH" 2>/dev/null || echo "0")
        NOW=$(date +%s)
        FETCH_AGE=$((NOW - FETCH_MTIME))
        check "Sync fresh (< 15 min)" test "$FETCH_AGE" -lt 900
    else
        check "Sync fresh (< 15 min)" false
    fi
    check "Cron job exists" sh -c "crontab -l 2>/dev/null | grep -q 'stack/infra'"
fi

$QUIET || echo ""
$QUIET || echo "Result: $PASS passed, $FAIL failed"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
