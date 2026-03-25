#!/usr/bin/env bash
# install.sh — Set up ~/.stack/infra/ on a server
#
# This script is the automated part of server onboarding. It:
# 1. Creates ~/.stack/ directory
# 2. Clones control-plane to ~/.stack/infra/ (or pulls if already cloned)
# 3. Sets up a cron job to pull every 5 minutes
# 4. Injects stack pointers into ~/.claude/CLAUDE.md and symlinks skills/
# 5. Runs a health check to verify everything works
#
# Usage:
#   bash install.sh                    # clone from GitHub
#   bash install.sh --repo <url>       # clone from a specific URL
#
# This script is idempotent — safe to re-run.

set -uo pipefail
# Note: -e is NOT set — we handle errors explicitly to provide clear messages

# ─── Configuration ───────────────────────────────────────────────────────────

STACK_DIR="$HOME/.stack"
INFRA_DIR="$STACK_DIR/infra"
REPO_URL="https://github.com/agastya-raj/control-plane.git"
CRON_INTERVAL="*/5 * * * *"
HAS_ERRORS=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)
            if [[ $# -lt 2 ]]; then
                echo "Error: --repo requires a URL argument"
                exit 1
            fi
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
warn() { echo "  [!] $1"; HAS_ERRORS=true; }
fail() { echo "  [✗] $1"; exit 1; }

# ─── Step 1: Create ~/.stack/ ────────────────────────────────────────────────

echo "Setting up ~/.stack/infra/ ..."

if [[ ! -d "$STACK_DIR" ]]; then
    mkdir -p "$STACK_DIR" || fail "Could not create $STACK_DIR"
    info "Created $STACK_DIR"
else
    info "$STACK_DIR already exists"
fi

# ─── Step 2: Clone or pull control-plane ─────────────────────────────────────

if [[ -d "$INFRA_DIR/.git" ]]; then
    info "$INFRA_DIR already cloned — pulling latest"
    if ! git -C "$INFRA_DIR" pull --ff-only 2>&1; then
        warn "Pull failed — continuing with existing checkout (may be stale)"
    fi
elif [[ -L "$INFRA_DIR" ]]; then
    info "$INFRA_DIR is a symlink (Mac dev setup) — skipping clone"
else
    info "Cloning $REPO_URL → $INFRA_DIR"
    if ! git clone "$REPO_URL" "$INFRA_DIR" 2>&1; then
        fail "Clone failed — check network and repo URL"
    fi
fi

# ─── Step 3: Set up cron sync ────────────────────────────────────────────────

# Only set up cron if this is a real clone (not a symlink on Mac)
if [[ -d "$INFRA_DIR/.git" && ! -L "$INFRA_DIR" ]]; then
    CRON_CMD="cd \"$INFRA_DIR\" && git pull --ff-only >> /tmp/stack-infra-sync.log 2>&1"
    CRON_LINE="$CRON_INTERVAL $CRON_CMD"

    # Get existing crontab (empty string if none exists)
    EXISTING_CRON=$(crontab -l 2>/dev/null || true)

    if echo "$EXISTING_CRON" | grep -q "stack/infra"; then
        info "Cron job already exists"
    else
        if echo "$EXISTING_CRON" | grep -q .; then
            # Append to existing crontab
            (echo "$EXISTING_CRON"; echo "$CRON_LINE") | crontab -
        else
            # No existing crontab — create fresh
            echo "$CRON_LINE" | crontab -
        fi

        if crontab -l 2>/dev/null | grep -q "stack/infra"; then
            info "Cron job installed (pull every 5 min)"
        else
            warn "Cron job installation may have failed"
        fi
    fi
else
    info "Skipping cron (symlink or no .git — Mac dev setup)"
fi

# ─── Step 4: Inject stack pointers into CLAUDE.md + symlink skills/ ──────────

CLAUDE_DIR="$HOME/.claude"
INJECT_FILE="$INFRA_DIR/claude/stack_inject.md"

if [[ ! -d "$CLAUDE_DIR" ]]; then
    mkdir -p "$CLAUDE_DIR" || fail "Could not create $CLAUDE_DIR"
    info "Created $CLAUDE_DIR"
fi

# Inject stack pointers into CLAUDE.md (doesn't replace — appends/updates)
if [[ ! -f "$INJECT_FILE" ]]; then
    warn "Stack inject file not found at $INJECT_FILE — skipping CLAUDE.md injection"
else
    CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
    # Resolve symlinks so file operations work on the real file
    if [[ -L "$CLAUDE_MD" ]]; then
        CLAUDE_MD_REAL=$(readlink -f "$CLAUDE_MD" 2>/dev/null || readlink "$CLAUDE_MD" 2>/dev/null)
    else
        CLAUDE_MD_REAL="$CLAUDE_MD"
    fi

    if [[ -f "$CLAUDE_MD" ]] && grep -q "STACK_INJECT_START" "$CLAUDE_MD"; then
        # Already injected — replace with latest version via temp file
        sed '/STACK_INJECT_START/,/STACK_INJECT_END/d' "$CLAUDE_MD_REAL" > "$CLAUDE_MD_REAL.tmp"
        cat "$INJECT_FILE" >> "$CLAUDE_MD_REAL.tmp"
        mv "$CLAUDE_MD_REAL.tmp" "$CLAUDE_MD_REAL"
        info "CLAUDE.md stack injection updated"
    elif [[ -f "$CLAUDE_MD" ]]; then
        # CLAUDE.md exists but no injection yet — append
        echo "" >> "$CLAUDE_MD"
        cat "$INJECT_FILE" >> "$CLAUDE_MD"
        info "Stack pointers injected into existing CLAUDE.md"
    else
        # No CLAUDE.md — create with just the injection
        cat "$INJECT_FILE" > "$CLAUDE_MD"
        info "CLAUDE.md created with stack pointers"
    fi
fi

# Symlink skills/ directory
SKILLS_DIR="$CLAUDE_DIR/skills"
if [[ ! -d "$SKILLS_DIR" ]]; then
    mkdir -p "$SKILLS_DIR"
fi

if [[ -d "$INFRA_DIR/skills" ]]; then
    FOUND_SKILLS=false
    for skill in "$INFRA_DIR/skills"/*/; do
        # Guard against empty glob (no subdirectories)
        [[ -d "$skill" ]] || continue
        FOUND_SKILLS=true
        skill_name=$(basename "$skill")
        if [[ -L "$SKILLS_DIR/$skill_name" ]]; then
            info "Skill '$skill_name' already symlinked"
        elif [[ -e "$SKILLS_DIR/$skill_name" ]]; then
            warn "Skill '$skill_name' exists but is not a symlink — skipping"
        else
            if ln -sf "$skill" "$SKILLS_DIR/$skill_name" 2>/dev/null; then
                info "Skill '$skill_name' symlinked"
            else
                warn "Failed to symlink skill '$skill_name'"
            fi
        fi
    done
    if [[ "$FOUND_SKILLS" == "false" ]]; then
        info "skills/ directory is empty — no skills to symlink"
    fi
else
    info "No skills/ directory in infra — skipping skill symlinks"
fi

# ─── Step 5: Health check ────────────────────────────────────────────────────

echo ""
echo "Health check:"

PASS=0
TOTAL=0

check() {
    local label="$1"
    shift
    TOTAL=$((TOTAL + 1))
    if "$@" > /dev/null 2>&1; then
        info "PASS: $label"
        PASS=$((PASS + 1))
    else
        warn "FAIL: $label"
    fi
}

check "~/.stack/infra/ exists" test -d "$INFRA_DIR"
check "registry/servers.yaml readable" test -f "$INFRA_DIR/registry/servers.yaml"
check "infra.md readable" test -f "$INFRA_DIR/infra.md"
check "CLAUDE.md has stack injection" grep -q "STACK_INJECT_START" "$CLAUDE_DIR/CLAUDE.md"
check "git works in infra dir" git -C "$INFRA_DIR" log --oneline -1

if [[ -d "$INFRA_DIR/.git" && ! -L "$INFRA_DIR" ]]; then
    check "cron job installed" sh -c "crontab -l 2>/dev/null | grep -q 'stack/infra'"
fi

echo ""
echo "Result: $PASS/$TOTAL checks passed"

if [[ "$HAS_ERRORS" == "true" || $PASS -ne $TOTAL ]]; then
    echo "⚠ Some issues detected — review the output above"
    exit 1
else
    echo "✓ install.sh complete — ~/.stack/infra/ is ready"
    exit 0
fi
