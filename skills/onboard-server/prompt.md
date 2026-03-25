# /onboard-server — Full server onboarding guide

Walk the user through onboarding a server into the infrastructure mesh. This skill adapts to each server's needs — not every server needs every step.

## Prerequisites

The server must already be registered in the control-plane registry (`registry/servers.yaml`). If not, run `protocols/discover_server.md` and `protocols/register_server.md` first.

## Flow

### Step 1: Run install.sh

Check if `~/.stack/infra/` already exists on the target server. If not, run the install script:

```bash
ssh <server_alias> "curl -fsSL https://raw.githubusercontent.com/agastya-raj/control-plane/main/sync/install.sh | bash"
```

Or if the server doesn't have internet access to GitHub:
```bash
scp sync/install.sh <server_alias>:/tmp/install.sh
ssh <server_alias> "bash /tmp/install.sh"
```

Verify install succeeded by checking the output. All health checks should pass.

### Step 2: Install Claude Code (user-assisted)

Ask the user: "Do you want to install Claude Code on this server?"

If yes, guide them:
1. SSH into the server: `ssh <server_alias>`
2. Install Claude Code: `curl -fsSL https://claude.ai/install.sh | sh`
3. Authenticate: `claude login` (requires browser or API key — user must do this)
4. Verify: `claude --version`

If the server already has Claude Code, skip this step.

### Step 3: Install Codex (user-assisted)

Ask the user: "Do you want to install Codex on this server?"

If yes, guide them:
1. Install Codex: `npm install -g @openai/codex` (requires Node.js)
2. Authenticate: the user handles API key setup
3. Verify: `codex --version`

If Node.js isn't installed, note that it's needed and let the user decide whether to install it.

### Step 4: Install Eternal Terminal (user-assisted)

Ask the user: "Do you want to set up ET (Eternal Terminal) for persistent connections to this server?"

If yes, guide them:
1. Install ET on the server:
   - Ubuntu/Debian: `sudo apt install et`
   - macOS: `brew install MisterTea/et/et`
2. Verify the ET daemon is running: `systemctl is-active etserver` (Linux)
3. Test from Mac: `et <server_alias>`
4. Verify persistence: connect via ET, sleep Mac briefly, verify session survives

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
- install.sh: ✓/✗
- Claude Code: ✓/skipped
- Codex: ✓/skipped
- ET: ✓/skipped
- Health check: all passing / N issues

Remind the user: "All new apps deployed to this server must be registered via `protocols/register_app.md`."
