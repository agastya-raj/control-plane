# Protocol: Provision a Server

Prepare a new server for the infrastructure mesh. This is a checklist — most steps are done manually or by the user. The agent confirms each item is complete before proceeding.

**This protocol runs once per server, before discovery.** It ensures the server is reachable and ready to be onboarded.

## Checklist

Work through each item. Confirm with the user that each step is done before moving on.

### 1. Physical/VM access
- [ ] Server is powered on and accessible (physically or via existing remote access)
- [ ] You know the server's hostname, OS, and login credentials
- [ ] The server has internet access

### 2. Tailscale
- [ ] Tailscale is installed on the server
- [ ] Server is connected to the tailnet (`tailscale status` shows "logged in")
- [ ] Server is visible from Mac (`tailscale ping <hostname>` works)
- [ ] Tailscale IP noted: `tailscale ip -4`

### 3. SSH access
- [ ] SSH server is running on the target (`sshd` or equivalent)
- [ ] SSH key from Mac is authorized on the target (`~/.ssh/authorized_keys`)
- [ ] Passwordless SSH works from Mac: `ssh <user>@<tailscale_ip> hostname`

### 4. SSH alias
- [ ] `~/.ssh/config` on Mac has an entry for this server:
```
Host <alias>
    HostName <tailscale_ip>
    User <username>
```
- [ ] `ssh <alias> hostname` works from Mac

### 5. Basic tools
- [ ] `git` is installed on the server
- [ ] `sudo` works without password (required — discovery and install protocols use sudo non-interactively)

### 6. 1Password (secrets management)
Secrets live in 1Password (vault = former Doppler project, item = former config); hosts read them with a read-only service account through `secret-tool` (repo `agastya-raj/doppler_migration`, see its PLAN.md). Doppler is only a synced mirror until it is decommissioned.
- [ ] 1Password CLI installed from the official apt repo: import the key to `/usr/share/keyrings/1password-archive-keyring.gpg`, add `deb [arch=<arch> signed-by=...] https://downloads.1password.com/linux/debian/<arch> stable main`, install the debsig policy, then `sudo apt-get install 1password-cli`; `op --version`
- [ ] `secret-tool` installed for the operator user: `git clone git@github.com:agastya-raj/doppler_migration.git ~/code/doppler_migration && cd ~/code/doppler_migration && uv tool install --editable .`; `sudo ln -sfn ~/.local/bin/secret-tool /usr/local/bin/secret-tool` so root finds it too
- [ ] Service account created on the Mac, read-only and scoped to the vaults this host needs: `op service-account create <server>-apps --vault personal_keys:read_items [--vault <other>:read_items] --raw`; save the token as a Personal-vault item `SA <server>-apps` (service accounts are immutable: to change scope, create a new one and revoke the old in the web UI)
- [ ] Token placed on the server through a pipe, never a transcript: `op read "op://Personal/SA <server>-apps/credential" | ssh <server> 'sudo install -d -m 0755 /etc/1password/tokens && sudo install -m 0600 -o root -g root /dev/stdin /etc/1password/tokens/<server>-apps && sudo ln -sfn /etc/1password/tokens/<server>-apps /etc/1password/token'`; for the operator user: `... | ssh <server> 'install -d -m 0700 ~/.config/1password && install -m 0600 /dev/stdin ~/.config/1password/token'`
- [ ] Verified: `secret-tool ls` (user) and `sudo secret-tool ls` (root) list the personal_keys/dev keys; `OP_SERVICE_ACCOUNT_TOKEN=$(cat ~/.config/1password/token) op service-account ratelimit` shows the budget (Individual plan: 1,000 requests/day for all service accounts — fetch once per process start, never per call; cache shell env for 1 h)

### 7. Optional (depends on server role)
- [ ] Docker installed and running (if this server will run containers)
- [ ] Python 3 available (for future scripts/tools)

## After provisioning

Once all required items are confirmed, proceed to:
1. `protocols/discover_server.md` — automated audit
2. User triage — review discovery report
3. `protocols/register_server.md` — register confirmed items

## Notes

- **This is intentionally a checklist, not automation.** Provisioning is rare (new servers don't appear often) and involves system-level changes that need human judgment.
- **The agent's role is to confirm**, not to perform. Walk through each item with the user, verify it's done, and flag anything missing.
- **Tailscale is mandatory.** Every server in the mesh must be on the tailnet. No exceptions.
