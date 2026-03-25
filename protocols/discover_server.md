# Protocol: Discover a Server

Gather all information about a server before onboarding. This protocol produces a **discovery report** — raw data with no decisions. The user reviews the report and decides what to register.

**This protocol is fully automated.** An agent can run it end-to-end without user input. Passwordless sudo is available on all servers.

## Prerequisites

- Server has been provisioned (`protocols/provision_server.md` checklist complete)
- SSH access works from Mac: `ssh <alias> hostname`

## Steps

### 1. Gather identity

SSH into the server and collect:

```bash
hostname                      # → hostname
tailscale ip -4               # → tailscale_ip
whoami                        # → user

# OS version
lsb_release -ds 2>/dev/null || cat /etc/os-release 2>/dev/null | head -2  # Linux
# or: sw_vers                 # macOS
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
sysctl -n hw.physicalcpu              # total physical cores
sysctl -n hw.logicalcpu               # logical threads
sysctl -n hw.memsize                  # RAM in bytes (÷ 1073741824 for GB)
df -h /
```

### 3. Check capabilities

For each capability, check two things: (1) is the binary/package **installed**? (2) is the service **running**?

| Capability | Installed? | Running? |
|------------|-----------|---------|
| docker | `which docker` | `docker ps` (no error) |
| caddy | `which caddy` | `systemctl is-active caddy` returns "active" |
| ollama | `which ollama` | `systemctl is-active ollama` returns "active" |
| jupyter | `which jupyter` | `systemctl is-active jupyter` returns "active" |
| claude_code | `which claude` | `claude --version` |
| symphony | `test -f ~/.stack/symphony/projects.json` or `test -f ~/.symphony/projects.json` | — |
| et | `which et` or `which etserver` | — |
| tailscale | `which tailscale` | `tailscale status` (no error) |

**Capabilities reflect what's installed**, not what's currently running. A server with Docker installed but temporarily stopped still has the `docker` capability. Report running status separately in the report so the user knows the current state.

### 4. Discover services

On Linux:
```bash
# Docker containers — names, ports, status
docker ps --format '{{.Names}}\t{{.Ports}}\t{{.Status}}' 2>/dev/null

# Docker compose file paths for each container
# Note: this returns the project directory; the actual file is usually docker-compose.yml inside it
docker ps --format '{{.Names}}' 2>/dev/null | xargs -I{} \
  docker inspect --format='{{.Name}}: {{index .Config.Labels "com.docker.compose.project.working_dir"}}/{{index .Config.Labels "com.docker.compose.project.config_files"}}' {} 2>/dev/null

# Systemd services (filter system noise)
systemctl list-units --type=service --state=running --no-pager --no-legend \
  | grep -v -E 'systemd|dbus|cron|ssh|network|snap|udev|journal|login|polkit|multipathd'

# Ports for all listening services
sudo ss -tlnp | grep -v '127.0.0.53'
```

On macOS:
```bash
docker ps --format '{{.Names}}\t{{.Ports}}\t{{.Status}}' 2>/dev/null

# macOS doesn't have systemctl — check for launchd user services
launchctl list 2>/dev/null | grep -v -E 'com.apple|application.com' | head -20

# Listening ports
lsof -iTCP -sTCP:LISTEN -nP 2>/dev/null | grep -v -E 'mDNS|rapportd|sharingd'
```

### 5. Check installed runtimes

Check for common language runtimes and tools beyond the core capabilities:

```bash
python3 --version 2>/dev/null
node --version 2>/dev/null
go version 2>/dev/null
rustc --version 2>/dev/null
java --version 2>/dev/null
uv --version 2>/dev/null
```

Note which are present — useful for understanding what the server can run and for future deployments.

### 6. Discover repos

On Linux:
```bash
# Find repos (maxdepth 4 to catch /home/user/code/repo/.git)
find /home -maxdepth 4 -name '.git' -type d 2>/dev/null | sed 's/\/.git$//' | while read -r repo; do
  remote=$(git -C "$repo" remote get-url origin 2>/dev/null || echo "no remote")
  echo "$repo → $remote"
done
```

On macOS:
```bash
find ~/code -maxdepth 3 -name '.git' -type d 2>/dev/null | sed 's/\/.git$//' | while read -r repo; do
  remote=$(git -C "$repo" remote get-url origin 2>/dev/null || echo "no remote")
  echo "$repo → $remote"
done
```

### 7. Check Caddy config (if Caddy is present)

**Warning:** Caddy configs may contain secrets (API tokens, auth credentials) in environment variable references or inline values. When including Caddy config in the discovery report, **summarize the routing rules only** (which subdomains point where). Do not include the full config verbatim.

```bash
# Summarize subdomain routing — look for site blocks, host matchers, and reverse_proxy targets
sudo grep -E '(^[a-zA-Z].*\{|host |reverse_proxy )' /etc/caddy/Caddyfile /etc/caddy/apps.caddy 2>/dev/null
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
- OS: ... (e.g., "Ubuntu 24.04 LTS" or "macOS 15.3")

### Hardware
- CPU: ... (X cores, Y threads)
- RAM: X GB
- Disk: X GB
- GPU: ... (X GB VRAM)  [or "None"]

### Capabilities (installed)
[list of all installed capabilities — these go in servers.yaml]

### Running Status
[for each capability, note if it's currently running or stopped]

### Runtimes
[list of detected language runtimes and versions]

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
| Path | Remote |
|------|--------|
| ...  | ...    |

### Caddy Config
[subdomain routing summary]
```

**Do not make any decisions about what to register.** Present all data and let the user decide. The user will then use `protocols/register_server.md` with their confirmed selections.
