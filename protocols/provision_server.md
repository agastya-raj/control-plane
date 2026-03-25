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
- [ ] `sudo` works without password (or user confirms sudo policy)

### 6. Optional (depends on server role)
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
