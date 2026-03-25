# Protocol: Register a New Server

Add a server to the control-plane registry so that agents and tools know it exists, how to reach it, and what it can do.

**Important:** All registry edits happen on Mac and push to GitHub. Steps 1-5 gather information from the target server via SSH. Steps 6-9 are done on Mac.

## Prerequisites

- SSH access to the target server from Mac (via Tailscale)
- The server has Tailscale installed and connected
- An SSH alias configured in `~/.ssh/config` on Mac (e.g., `Host gpu`)

## Steps

### 1. Gather identity info

SSH into the server and collect:

```bash
hostname                      # → hostname field
tailscale ip -4               # → tailscale_ip field
whoami                        # → user field
```

Record the SSH alias you used to connect (the `Host` entry in `~/.ssh/config`).

### 2. Audit hardware

On Linux:
```bash
# CPU — note: total cores = cores_per_socket × sockets
lscpu | grep -E 'Model name|Core\(s\) per socket|Thread\(s\) per core|Socket'

# RAM (note the total in GB)
free -h | grep Mem

# Disk (note root partition size in GB)
df -h /

# GPU (if applicable)
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
```

On macOS:
```bash
# CPU
sysctl -n machdep.cpu.brand_string
sysctl -n hw.perflevel0.physicalcpu   # physical cores (performance)
sysctl -n hw.logicalcpu               # logical threads

# RAM (bytes → divide by 1073741824 for GB)
sysctl -n hw.memsize

# Disk
df -h /
```

Convert all values to the schema's units: cores (integer), threads (integer), ram_gb (integer), disk_gb (integer).

### 3. Check capabilities

Run each check and note which capabilities are present:

| Capability | Check command |
|------------|--------------|
| docker | `docker ps` (runs without error) |
| caddy | `systemctl is-active caddy` or `caddy version` |
| ollama | `systemctl is-active ollama` or `ollama --version` |
| jupyter | `systemctl is-active jupyter` or `jupyter --version` |
| claude_code | `claude --version` |
| symphony | `test -f ~/.symphony/projects.json` |
| et | `which et` or `which etserver` |
| tailscale | `tailscale status` (should always be present) |

Add any capability that is confirmed working. Skip capabilities that aren't installed.

### 4. Discover services

List running services that are relevant (not system-level):

On Linux:
```bash
# Docker containers
docker ps --format '{{.Names}}\t{{.Ports}}\t{{.Status}}' 2>/dev/null

# Systemd services (filter system noise)
systemctl list-units --type=service --state=running --no-pager --no-legend \
  | grep -v -E 'systemd|dbus|cron|ssh|network|snap|udev|journal|login|polkit|multipathd'
```

On macOS:
```bash
docker ps --format '{{.Names}}\t{{.Ports}}\t{{.Status}}' 2>/dev/null
```

For each relevant service, note: name, type (systemd/docker/binary), and port.

### 5. Discover repos

While still on the server, find git repos:

On Linux:
```bash
find /home -maxdepth 3 -name '.git' -type d 2>/dev/null
```

On macOS:
```bash
find ~/code -maxdepth 3 -name '.git' -type d 2>/dev/null
```

Note the paths of important repos for step 8.

### 6. Determine roles (on Mac)

Back on Mac, assign one or more roles based on what you observed:

| Role | When to assign |
|------|---------------|
| compute | Has GPU or is used for heavy computation / ML |
| homelab | Runs self-hosted services (wiki, git, monitoring, etc.) |
| testbed | Used for research experiments |
| dev | Primary development machine |
| media | Runs media services (Plex, Jellyfin, etc.) |
| sandbox | Sandboxed/isolated execution environment |

Roles are extensible — add custom ones if needed (e.g., `hpc`, `storage`).

### 7. Fill the template (on Mac)

Copy `templates/server_entry.yaml` and fill in all gathered data:

- Replace all `<PLACEHOLDER>` values with real data
- Set `roles` list (replace `[]`)
- Set `capabilities` list (uncomment applicable ones)
- Fill `hardware` block (use `null` for unknowns)
- Add discovered services
- Set `gateway` if this server is only reachable through another server
- Set `domain` if it serves web traffic
- Set `added` and `last_audit` to today's date

### 8. Add to registry (on Mac)

Insert the filled entry into `registry/servers.yaml` under the `servers:` key.

If this is the first entry, replace `servers: {}` with:
```yaml
servers:
  <your_entry_here>
```

For important repos discovered in step 5, add them to `registry/repos.yaml` using `templates/repo_entry.yaml`. If a repo is also a deployed app, **also** register the app via `protocols/register_app.md` — both the repo entry and app entry are needed.

### 9. Commit and push (on Mac)

```bash
git add registry/servers.yaml registry/repos.yaml registry/apps.yaml
git commit -m "Register server: <server_name>"
git push
```

## Verification

After registration, confirm:

- [ ] Entry has no `<PLACEHOLDER>` values remaining
- [ ] SSH alias works: `ssh <ssh_alias> hostname`
- [ ] Capabilities are accurate: spot-check 2-3 from the server
- [ ] YAML is valid: `python3 -c "import json; open('/dev/null')"`  — or just ensure the file has no syntax errors by inspection

## Notes

- **Mac is the primary writer.** Gather info via SSH, but all edits to registry files happen on Mac. Other servers are read-only and pull via cron.
- **Gateway servers:** If the server is behind another server (e.g., `turing` reachable only from `gpu`), set `gateway: gpu`. Only single-hop gateways are supported currently.
- **Re-auditing:** To update an existing server, re-run steps 1-5 and update the entry. Set `last_audit` to today.
