# Protocol: Agent Orientation

What to do when you first start a session on any server in the infrastructure mesh.

## Quick orientation (30 seconds)

1. **Read `infra.md`** in this repo — it's the infrastructure knowledge hub
2. **Identify your server:**
   ```bash
   hostname
   ```
   Look up this hostname in `registry/servers.yaml` (the `hostname` field) to find your server key, roles, capabilities, and what's expected to be running.

3. **Check what's registered here:**
   Read `registry/apps.yaml` and look for entries where `server` matches your server key (not hostname). For example, if your server key is `gpu`, look for `server: "gpu"` entries.

## Full orientation (when you need context)

### Understand the infrastructure

- **`registry/servers.yaml`** — all servers, how to reach them, what they do
- **`registry/apps.yaml`** — all deployed apps, endpoints, health checks
- **`registry/repos.yaml`** — all repos, where they're cloned

### Check current state

On Linux:
```bash
# What's actually running?
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null

# What systemd services are active?
systemctl list-units --type=service --state=running --no-pager --no-legend \
  | grep -v -E 'systemd|dbus|cron|ssh|network|snap|udev|journal|login|polkit|multipathd'
```

On macOS:
```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null

# List running services (macOS has no systemctl)
launchctl list 2>/dev/null | head -20
```

Compare what's actually running against what's registered in `apps.yaml`. Flag any discrepancies:
- Registered but not running → may need restart or investigation
- Running but not registered → consider registering it

### Check recent changes

```bash
# What changed in the registry recently?
cd ~/.agastya && git log --oneline -10
```

## When to re-orient

- **Starting a new session** — quick orientation (steps 1-3)
- **Asked to deploy or manage something** — full orientation, then read the relevant protocol
- **Something seems wrong** — compare registered state vs actual state
- **First time on this server** — full orientation + check what needs registering

## Key protocols

| Task | Protocol |
|------|----------|
| Provision a new server | `protocols/provision_server.md` (checklist with user) |
| Discover a server | `protocols/discover_server.md` (automated audit) |
| Register a server | `protocols/register_server.md` (after discovery + user triage) |
| Register an app | `protocols/register_app.md` |
| Deploy an app | `protocols/deploy.md` *(not yet created)* |
| Hand off compute | `protocols/compute_handoff.md` *(not yet created)* |

## Conventions

- **Mac is the primary writer** — registry edits happen on Mac, push to GitHub, servers pull
- **YAML for data, Markdown for docs** — all registry files are YAML, all protocols are Markdown
- **snake_case everywhere** — file names, YAML keys, server names
- **Prefer protocols when available** — they ensure the registry stays in sync with reality. For tasks without a protocol yet, proceed carefully and update the registry manually.
