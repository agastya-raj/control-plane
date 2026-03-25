# /onboard-server — Full server onboarding guide

Walk the user through onboarding a server into the infrastructure mesh. This skill adapts to each server's needs — not every server needs every step.

## Prerequisites

The server must already be registered in the control-plane registry (`registry/servers.yaml`). If not, run discovery and registration first:
1. `protocols/discover_server.md` — automated audit
2. Triage with user — review report, decide what to register
3. `protocols/register_server.md` — add confirmed items to registry

Verify registration: check that the server key exists in `registry/servers.yaml`.

## Flow

### Step 1: Run install.sh

Check if `~/.stack/infra/` already exists on the target server:
```bash
ssh <server_alias> "test -d ~/.stack/infra && echo 'already installed' || echo 'needs install'"
```

If not installed, run:
```bash
ssh <server_alias> "curl -fsSL https://raw.githubusercontent.com/agastya-raj/control-plane/main/sync/install.sh | bash"
```

If the server can't reach GitHub, copy the entire repo:
```bash
rsync -az ~/code/control-plane/ <server_alias>:/tmp/control-plane/
ssh <server_alias> "bash /tmp/control-plane/sync/install.sh --repo /tmp/control-plane"
```

Verify install succeeded — all health checks should pass.

### Step 2: Install Claude Code (user-assisted)

Ask the user: "Do you want to install Claude Code on this server?"

If yes:
1. Check if already installed: `ssh <server_alias> "which claude 2>/dev/null && claude --version || echo 'not installed'"`
2. If not installed, tell the user to SSH in and install it following the official Anthropic docs
3. Authentication requires browser or API key — the user must do this themselves
4. Verify: `ssh <server_alias> "claude --version"`
5. Update `registry/servers.yaml` — add `claude_code` to capabilities

### Step 3: Install Codex (user-assisted)

Ask the user: "Do you want to install Codex on this server?"

If yes:
1. Check if already installed: `ssh <server_alias> "which codex 2>/dev/null || echo 'not installed'"`
2. If not installed, tell the user to SSH in and install it following the official OpenAI docs
3. Authentication — the user handles API key setup
4. Verify: `ssh <server_alias> "codex --version"`

Note: Codex requires Node.js. If Node.js isn't installed, let the user know and ask if they want to install it first.

### Step 4: Install Eternal Terminal (user-assisted)

Ask the user: "Do you want to set up ET (Eternal Terminal) for persistent connections to this server?"

If yes, guide them:
1. Install ET on the server:
   - Ubuntu/Debian: `sudo apt install et`
   - macOS: `brew install MisterTea/et/et`
2. Verify the ET daemon is running: `systemctl is-active etserver` (Linux)
3. Test from Mac: `et <server_alias>`
4. Verify persistence: connect via ET, sleep Mac briefly, verify session survives
5. Update `registry/servers.yaml` — add `et` to capabilities

ET is recommended for servers you connect to frequently. Skip for rarely-used servers.

### Step 5: Server-specific setup

Ask the user: "Anything else specific to this server?"

Common extras:
- **Docker**: `sudo apt install docker.io && sudo usermod -aG docker $USER`
- **Python/uv**: install if needed for future tools
- **GPU drivers**: for compute servers
- **Tailscale ACL updates**: if access rules need adjusting

### Step 6: Verify

Run the health check:
```bash
ssh <server_alias> "bash ~/.stack/infra/sync/health_check.sh"
```

Update the server's registry entry if new capabilities were added (Claude Code, ET, etc.):
- Update `capabilities` list in `registry/servers.yaml`
- Update `last_audit` date
- Commit and push

### Summary

Print what was done:
- install.sh: passed / issues
- Claude Code: installed / skipped
- Codex: installed / skipped
- ET: installed / skipped
- Health check: all passing / N issues

Remind the user: "All new apps deployed to this server must be registered via `protocols/register_app.md`."
