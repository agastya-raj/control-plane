#!/usr/bin/env bash
# install.sh — Set up ~/.stack/infra/ on a server
#
# This script is the automated part of server onboarding. It:
# 1. Creates ~/.stack/ directory
# 2. Clones control-plane to ~/.stack/infra/ (or pulls if already cloned)
# 3. Sets up a cron job to pull every 5 minutes
# 4. Symlinks CLAUDE.md to ~/.claude/CLAUDE.md
# 5. Runs a health check to verify everything works
#
# Usage:
#   bash install.sh                    # clone from GitHub
#   bash install.sh --repo <url>       # clone from a specific URL
#
# This script is idempotent — safe to re-run.

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────

STACK_DIR="$HOME/.stack"
INFRA_DIR="$STACK_DIR/infra"
REPO_URL="https://github.com/agastya-raj/control-plane.git"
CRON_INTERVAL="*/5 * * * *"
CRON_COMMENT="# control-plane sync"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)
            REPO_URL="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: bash install.sh [--repo <url>]"
            exit 1
            ;;
    esac
done

# ─── Helpers ─────────────────────────────────────────────────────────────────

info() { echo "  [+] $1"; }
warn() { echo "  [!] $1"; }
fail() { echo "  [✗] $1"; exit 1; }

# ─── Step 1: Create ~/.stack/ ────────────────────────────────────────────────

echo "Setting up ~/.stack/infra/ ..."

if [[ ! -d "$STACK_DIR" ]]; then
    mkdir -p "$STACK_DIR"
    info "Created $STACK_DIR"
else
    info "$STACK_DIR already exists"
fi

# ─── Step 2: Clone or pull control-plane ─────────────────────────────────────

if [[ -d "$INFRA_DIR/.git" ]]; then
    info "$INFRA_DIR already cloned — pulling latest"
    git -C "$INFRA_DIR" pull --ff-only || warn "Pull failed (check for conflicts)"
elif [[ -L "$INFRA_DIR" ]]; then
    info "$INFRA_DIR is a symlink (Mac dev setup) — skipping clone"
else
    info "Cloning $REPO_URL → $INFRA_DIR"
    git clone "$REPO_URL" "$INFRA_DIR" || fail "Clone failed"
fi

# ─── Step 3: Set up cron sync ────────────────────────────────────────────────

# Only set up cron if this is a real clone (not a symlink on Mac)
if [[ -d "$INFRA_DIR/.git" && ! -L "$INFRA_DIR" ]]; then
    CRON_CMD="cd $INFRA_DIR && git pull --ff-only >> /tmp/stack-infra-sync.log 2>&1"

    if crontab -l 2>/dev/null | grep -q "stack-infra-sync"; then
        info "Cron job already exists"
    else
        (crontab -l 2>/dev/null; echo "$CRON_COMMENT"; echo "$CRON_INTERVAL $CRON_CMD # stack-infra-sync") | crontab -
        info "Cron job installed (pull every 5 min)"
    fi
else
    info "Skipping cron (symlink or no .git — Mac dev setup)"
fi

# ─── Step 4: Symlink CLAUDE.md ───────────────────────────────────────────────

CLAUDE_DIR="$HOME/.claude"

if [[ ! -d "$CLAUDE_DIR" ]]; then
    mkdir -p "$CLAUDE_DIR"
    info "Created $CLAUDE_DIR"
fi

if [[ -L "$CLAUDE_DIR/CLAUDE.md" ]]; then
    info "CLAUDE.md symlink already exists"
elif [[ -f "$CLAUDE_DIR/CLAUDE.md" ]]; then
    warn "CLAUDE.md already exists (not a symlink) — backing up to CLAUDE.md.bak"
    mv "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.bak"
    ln -sf "$INFRA_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    info "CLAUDE.md symlinked (old file backed up)"
else
    ln -sf "$INFRA_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    info "CLAUDE.md symlinked"
fi

# ─── Step 5: Health check ────────────────────────────────────────────────────

echo ""
echo "Health check:"

PASS=0
TOTAL=0

check() {
    TOTAL=$((TOTAL + 1))
    if eval "$2" > /dev/null 2>&1; then
        info "PASS: $1"
        PASS=$((PASS + 1))
    else
        warn "FAIL: $1"
    fi
}

check "~/.stack/infra/ exists" "test -d $INFRA_DIR"
check "registry/servers.yaml readable" "test -f $INFRA_DIR/registry/servers.yaml"
check "infra.md readable" "test -f $INFRA_DIR/infra.md"
check "CLAUDE.md symlink works" "test -L $CLAUDE_DIR/CLAUDE.md && test -f $CLAUDE_DIR/CLAUDE.md"
check "git works in infra dir" "git -C $INFRA_DIR log --oneline -1"

if [[ -d "$INFRA_DIR/.git" && ! -L "$INFRA_DIR" ]]; then
    check "cron job installed" "crontab -l 2>/dev/null | grep -q stack-infra-sync"
fi

echo ""
echo "Result: $PASS/$TOTAL checks passed"

if [[ $PASS -eq $TOTAL ]]; then
    echo "✓ install.sh complete — ~/.stack/infra/ is ready"
else
    echo "⚠ Some checks failed — review the output above"
fi
