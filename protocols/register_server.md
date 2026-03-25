# Protocol: Register a New Server

Add a server to the control-plane registry so that agents and tools know it exists, how to reach it, and what it can do.

## Prerequisites

- SSH access to the target server from Mac (via Tailscale)
- The server has Tailscale installed and connected
- An SSH alias configured in `~/.ssh/config` on Mac

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

```bash
# CPU
lscpu | grep -E 'Model name|Core\(s\) per socket|Thread\(s\) per core|Socket'
# or on macOS:
sysctl -n machdep.cpu.brand_string && sysctl -n hw.ncpu

# RAM
free -h | grep Mem            # Linux
# or: sysctl -n hw.memsize    # macOS (bytes)

# Disk
df -h /

# GPU (if applicable)
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
```

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

```bash
# Docker containers
docker ps --format '{{.Names}}\t{{.Ports}}\t{{.Status}}'

# Systemd services (filter system noise)
systemctl list-units --type=service --state=running --no-pager --no-legend \
  | grep -v -E 'systemd|dbus|cron|ssh|network|snap|udev|journal|login|polkit|multipathd'
```

For each relevant service, note: name, type (systemd/docker/binary), and port.

### 5. Determine roles

Assign one or more roles based on what the server is used for:

| Role | When to assign |
|------|---------------|
| compute | Has GPU or is used for heavy computation / ML |
| homelab | Runs self-hosted services (wiki, git, monitoring, etc.) |
| testbed | Used for research experiments |
| dev | Primary development machine |
| media | Runs media services (Plex, Jellyfin, etc.) |
| sandbox | Sandboxed/isolated execution environment |

Roles are extensible — add custom ones if needed (e.g., `hpc`, `storage`).

### 6. Fill the template

Copy `templates/server_entry.yaml` and fill in all gathered data:

- Replace all `<PLACEHOLDER>` values with real data
- Set `roles` list (replace `[]`)
- Set `capabilities` list (uncomment applicable ones)
- Fill `hardware` block (use `null` for unknowns)
- Add discovered services
- Set `gateway` if this server is only reachable through another server
- Set `domain` if it serves web traffic
- Set `added` and `last_audit` to today's date

### 7. Add to registry

Insert the filled entry into `registry/servers.yaml` under the `servers:` key.

If this is the first entry, replace `servers: {}` with:
```yaml
servers:
  <your_entry_here>
```

### 8. Discover and register repos

While on the server, find git repos:

```bash
find /home -maxdepth 3 -name '.git' -type d 2>/dev/null
```

For each important repo, follow `protocols/register_app.md` if it's a deployed app, or add it directly to `registry/repos.yaml` using `templates/repo_entry.yaml`.

### 9. Commit and push

```bash
git add registry/servers.yaml registry/repos.yaml
git commit -m "Register server: <server_name>"
git push
```

## Verification

After registration, confirm:

- [ ] Server entry parses correctly: `python3 -c "import yaml; print(yaml.safe_load(open('registry/servers.yaml'))['servers']['<name>']['tailscale_ip'])"`
- [ ] SSH alias works: `ssh <ssh_alias> hostname`
- [ ] Capabilities are accurate: spot-check 2-3 from the server
- [ ] No `<PLACEHOLDER>` values remain in the entry

## Notes

- **Mac is the primary writer.** All registry edits happen on Mac and push to GitHub. Other servers pull via cron.
- **Gateway servers:** If the server is behind another server (e.g., `turing` reachable only from `gpu`), set `gateway: gpu`. Only single-hop gateways are supported currently.
- **Re-auditing:** To update an existing server, re-run steps 2-5 and update the entry. Set `last_audit` to today.
