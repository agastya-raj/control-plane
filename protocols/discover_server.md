# Protocol: Discover a Server

Gather all information about a server before onboarding. This protocol produces a **discovery report** — raw data with no decisions. The user reviews the report and decides what to register.

**This protocol is fully automated.** An agent can run it end-to-end without user input. Passwordless sudo is available on all servers.

## Prerequisites

- SSH access to the target server from Mac (via Tailscale)
- The server has Tailscale installed and connected
- An SSH alias configured in `~/.ssh/config` on Mac (e.g., `Host gpu`)

## Steps

### 1. Gather identity

SSH into the server and collect:

```bash
hostname                      # → hostname
tailscale ip -4               # → tailscale_ip
whoami                        # → user
```

Record the SSH alias you used to connect (the `Host` entry in `~/.ssh/config`).

### 2. Audit hardware

On Linux:
```bash
# CPU — total_cores = cores_per_socket × sockets, total_threads = threads_per_core × total_cores
lscpu | grep -E 'Model name|Core\(s\) per socket|Thread\(s\) per core|Socket'

# RAM
free -h | grep Mem

# Disk
df -h /

# GPU (if applicable)
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
```

On macOS:
```bash
sysctl -n machdep.cpu.brand_string
sysctl -n hw.perflevel0.physicalcpu   # physical cores
sysctl -n hw.logicalcpu               # logical threads
sysctl -n hw.memsize                  # RAM in bytes (÷ 1073741824 for GB)
df -h /
```

### 3. Check capabilities

Run each check and note which are present:

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

### 4. Discover services

On Linux:
```bash
# Docker containers — names, ports, status
docker ps --format '{{.Names}}\t{{.Ports}}\t{{.Status}}' 2>/dev/null

# Docker compose file paths for each container
docker ps --format '{{.Names}}' 2>/dev/null | xargs -I{} \
  docker inspect --format='{{.Name}}: {{index .Config.Labels "com.docker.compose.project.working_dir"}}' {} 2>/dev/null

# Systemd services (filter system noise)
systemctl list-units --type=service --state=running --no-pager --no-legend \
  | grep -v -E 'systemd|dbus|cron|ssh|network|snap|udev|journal|login|polkit|multipathd'

# Ports for all listening services
sudo ss -tlnp | grep -v '127.0.0.53'
```

On macOS:
```bash
docker ps --format '{{.Names}}\t{{.Ports}}\t{{.Status}}' 2>/dev/null
```

### 5. Discover repos

On Linux:
```bash
find /home -maxdepth 3 -name '.git' -type d 2>/dev/null
```

On macOS:
```bash
find ~/code -maxdepth 3 -name '.git' -type d 2>/dev/null
```

### 6. Check Caddy config (if Caddy is present)

```bash
sudo cat /etc/caddy/Caddyfile 2>/dev/null
sudo cat /etc/caddy/apps.caddy 2>/dev/null
```

## Output: Discovery Report

Present all gathered data to the user in a structured format:

```
## Server: <hostname> (<ssh_alias>)

### Identity
- Hostname: ...
- Tailscale IP: ...
- User: ...
- SSH alias: ...

### Hardware
- CPU: ... (X cores, Y threads)
- RAM: X GB
- Disk: X GB
- GPU: ... (X GB VRAM)  [or "None"]

### Capabilities
[list of confirmed capabilities]

### Running Services
#### Docker Containers
| Name | Ports | Status | Compose Path |
|------|-------|--------|-------------|
| ...  | ...   | ...    | ...         |

#### Systemd Services
| Name | Port | Notes |
|------|------|-------|
| ...  | ...  | ...   |

### Repos Found
#### Active-looking (top-level)
| Path | Remote | Notes |
|------|--------|-------|
| ...  | ...    | ...   |

#### Archive/Documents
[list paths]

#### Skip (package managers, dotfile tools)
[list paths]

### Caddy Config
[subdomain routing summary]
```

**Do not make any decisions about what to register.** Present all data and let the user decide. The user will then use `protocols/register_server.md` with their confirmed selections.
