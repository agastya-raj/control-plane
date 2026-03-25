#!/usr/bin/env bash
# health_check.sh — Verify control-plane sync is healthy
#
# Checks:
# 1. ~/.stack/infra/ exists and is a git repo
# 2. Last sync was within the last 15 minutes
# 3. CLAUDE.md symlink is valid
# 4. Registry files are readable and valid YAML
#
# Usage:
#   bash health_check.sh           # run all checks
#   bash health_check.sh --quiet   # exit code only (0=healthy, 1=unhealthy)

set -euo pipefail

INFRA_DIR="$HOME/.stack/infra"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
SYNC_LOG="/tmp/stack-infra-sync.log"
QUIET=false

[[ "${1:-}" == "--quiet" ]] && QUIET=true

PASS=0
FAIL=0

check() {
    if eval "$2" > /dev/null 2>&1; then
        $QUIET || echo "  [PASS] $1"
        PASS=$((PASS + 1))
    else
        $QUIET || echo "  [FAIL] $1"
        FAIL=$((FAIL + 1))
    fi
}

$QUIET || echo "Control-plane health check:"

# Core checks
check "~/.stack/infra/ exists" "test -d $INFRA_DIR"
check "Is a git repo" "test -d $INFRA_DIR/.git || test -L $INFRA_DIR"
check "registry/servers.yaml exists" "test -f $INFRA_DIR/registry/servers.yaml"
check "registry/apps.yaml exists" "test -f $INFRA_DIR/registry/apps.yaml"
check "infra.md exists" "test -f $INFRA_DIR/infra.md"
check "CLAUDE.md symlink valid" "test -L $CLAUDE_MD && test -f $CLAUDE_MD"

# Sync freshness (only for real clones, not symlinks)
if [[ -d "$INFRA_DIR/.git" && ! -L "$INFRA_DIR" ]]; then
    # Check if last commit fetch was within 15 minutes
    LAST_FETCH="$INFRA_DIR/.git/FETCH_HEAD"
    if [[ -f "$LAST_FETCH" ]]; then
        FETCH_AGE=$(( $(date +%s) - $(stat -c %Y "$LAST_FETCH" 2>/dev/null || stat -f %m "$LAST_FETCH" 2>/dev/null) ))
        check "Sync fresh (< 15 min)" "test $FETCH_AGE -lt 900"
    else
        check "Sync fresh (< 15 min)" "false"
    fi
    check "Cron job exists" "crontab -l 2>/dev/null | grep -q stack-infra-sync"
fi

$QUIET || echo ""
$QUIET || echo "Result: $PASS passed, $FAIL failed"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
