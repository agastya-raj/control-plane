# Protocol: Register a New Server

Add a server to the control-plane registry so that agents and tools know it exists, how to reach it, and what it can do.

**Important:** All registry edits happen on Mac and push to GitHub. Steps 1-5 gather information from the target server via SSH. Steps 6-10 are done on Mac. Passwordless sudo is available on all servers.

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
# CPU — note: total_cores = cores_per_socket × sockets, total_threads = threads_per_core × total_cores
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
# Docker containers — names, ports, status, and compose file paths
docker ps --format '{{.Names}}\t{{.Ports}}\t{{.Status}}' 2>/dev/null
docker ps --format '{{.Names}}' | xargs -I{} \
  docker inspect --format='{{.Name}}: {{index .Config.Labels "com.docker.compose.project.working_dir"}}' {} 2>/dev/null

# Systemd services (filter system noise)
systemctl list-units --type=service --state=running --no-pager --no-legend \
  | grep -v -E 'systemd|dbus|cron|ssh|network|snap|udev|journal|login|polkit|multipathd'

# Find ports for systemd services
sudo ss -tlnp | grep -v '127.0.0.53'
```

On macOS:
```bash
docker ps --format '{{.Names}}\t{{.Ports}}\t{{.Status}}' 2>/dev/null
```

For each relevant service, note: name, type (systemd/docker/binary), port, and compose file path (if docker-compose).

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

Note the paths — you'll triage them in step 8.

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

### 7. Fill the server template (on Mac)

Copy `templates/server_entry.yaml` and fill in all gathered data:

- Replace all `<PLACEHOLDER>` values with real data
- Set `roles` list (replace `[]`)
- Set `capabilities` list (uncomment applicable ones)
- Fill `hardware` block (use `null` for unknowns)
- Add discovered services
- Set `gateway` if this server is only reachable through another server
- Set `domain` if it serves web traffic
- Set `added` and `last_audit` to today's date

### 8. Triage apps and repos with the user (on Mac)

**This step requires user input.** Present the discovered services and repos to the user and ask them to decide what to register.

**For apps/services:** Show the user the full list of discovered containers and services, then ask:
- Which of these are actively used and should be registered?
- Which are legacy/unused and should be skipped?
- Which are infrastructure that other apps depend on?

Only register apps the user confirms. Use `protocols/register_app.md` for each confirmed app.

**For repos:** Show the user the full list of discovered repos, then ask which to register. Skip:
- Package managers and shell tools (`.nvm`, `.oh-my-zsh`, etc.)
- Old backups and duplicates
- Abandoned experiments

For repos that are also deployed apps, register **both** the repo entry (in repos.yaml) and the app entry (in apps.yaml).

### 9. Add to registry (on Mac)

Insert the filled server entry into `registry/servers.yaml` under the `servers:` key.

If this is the first entry, replace `servers: {}` with:
```yaml
servers:
  <your_entry_here>
```

Add confirmed apps to `registry/apps.yaml` and confirmed repos to `registry/repos.yaml`.

### 10. Commit and push (on Mac)

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
- [ ] YAML is valid: `uv run --with pyyaml python3 -c "import yaml; yaml.safe_load(open('registry/servers.yaml')); print('Valid')"`

## Notes

- **Mac is the primary writer.** Gather info via SSH, but all edits to registry files happen on Mac. Other servers are read-only and pull via cron.
- **Gateway servers:** If the server is behind another server (e.g., `turing` reachable only from `gpu`), set `gateway: gpu`. Only single-hop gateways are supported currently.
- **Re-auditing:** To update an existing server, re-run steps 1-5 and update the entry. Set `last_audit` to today.
- **After onboarding:** Once a server is registered, all new apps deployed to it **must** be registered via `protocols/register_app.md`. If it's not in the registry, it doesn't exist.
