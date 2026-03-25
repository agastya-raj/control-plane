# Protocol: Agent Orientation

What to do when you first start a session on any server in the infrastructure mesh.

## Quick orientation (30 seconds)

1. **Read `infra.md`** in this repo — it's the infrastructure knowledge hub
2. **Identify your server:**
   ```bash
   hostname
   ```
   Look up this hostname in `registry/servers.yaml` to understand what server you're on, its roles, capabilities, and what's expected to be running.

3. **Check what's registered here:**
   ```bash
   # What apps should be running on this server?
   grep -A1 "server:" registry/apps.yaml | grep -B1 "<this_server_name>"
   ```

## Full orientation (when you need context)

### Understand the infrastructure

- **`registry/servers.yaml`** — all servers, how to reach them, what they do
- **`registry/apps.yaml`** — all deployed apps, endpoints, health checks
- **`registry/repos.yaml`** — all repos, where they're cloned

### Check current state

```bash
# What's actually running? (if Docker is available)
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

# What systemd services are active?
systemctl list-units --type=service --state=running --no-pager --no-legend \
  | grep -v -E 'systemd|dbus|cron|ssh|network|snap|udev|journal|login|polkit|multipathd'
```

Compare what's actually running against what's registered in `apps.yaml`. Flag any discrepancies:
- Registered but not running → may need restart or investigation
- Running but not registered → consider registering it

### Check recent changes

```bash
# What changed in the registry recently?
cd ~/.agastya && git log --oneline -10
```

### Check for active handoffs

```bash
# Any active compute handoffs involving this server?
ls handoffs/ 2>/dev/null
```

## When to re-orient

- **Starting a new session** — quick orientation (steps 1-3)
- **Asked to deploy or manage something** — full orientation, then read the relevant protocol
- **Something seems wrong** — compare registered state vs actual state
- **First time on this server** — full orientation + check what needs registering

## Key protocols

| Task | Protocol |
|------|----------|
| Onboard a new server | `protocols/register_server.md` |
| Register an app | `protocols/register_app.md` |
| Deploy an app | `protocols/deploy.md` *(future)* |
| Hand off compute | `protocols/compute_handoff.md` *(future)* |

## Conventions

- **Mac is the primary writer** — registry edits happen on Mac, push to GitHub, servers pull
- **YAML for data, Markdown for docs** — all registry files are YAML, all protocols are Markdown
- **snake_case everywhere** — file names, YAML keys, server names
- **Don't install or configure directly** — use the protocols. They ensure the registry stays in sync with reality.
