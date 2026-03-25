# Protocol: Register an App

Add a deployed application to the control-plane registry so agents know it exists, where it runs, and how to interact with it.

**Important:** All registry edits happen on Mac and push to GitHub. Steps 1-3 gather information from the target server via SSH. Steps 4-7 are done on Mac. Passwordless sudo is available on all servers.

## Prerequisites

- The server the app runs on must already be registered in `registry/servers.yaml`
- SSH access to that server from Mac

## Steps

### 1. Identify the app

Determine what you're registering:

- **Docker Compose app** — has a `docker-compose.yml` / `compose.yml`
- **Systemd service** — managed by `systemctl`
- **Binary / manual** — standalone process or manually started

### 2. Gather info from the server

SSH into the server and collect details based on deploy method:

**For docker-compose apps:**
```bash
# Find the compose file path for a running container
docker inspect --format='{{index .Config.Labels "com.docker.compose.project.working_dir"}}/{{index .Config.Labels "com.docker.compose.project.config_files"}}' <container_name>

# Or search for compose files (check both .yml and .yaml extensions)
find /home -maxdepth 4 \( -name 'docker-compose.yml' -o -name 'docker-compose.yaml' -o -name 'compose.yml' -o -name 'compose.yaml' \) 2>/dev/null

# Check running containers for this app
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}'

# If multi-service, list all services in the compose file
docker compose -f <compose_file> ps
```

**For systemd services:**
```bash
# Check the unit
systemctl status <service_name>

# Find the port — try these in order:
sudo ss -tlnp | grep <process_name>
systemctl cat <service_name>          # look for port in ExecStart or Environment
```

**For binaries:**
```bash
which <binary_name>
ps aux | grep <binary_name>
```

### 3. Check web access

If the app has a web interface:

```bash
# Check if it responds locally
curl -s -o /dev/null -w "%{http_code}" http://localhost:<port>/
curl -s -o /dev/null -w "%{http_code}" http://localhost:<port>/health
```

Note the endpoint URL (e.g., `https://myapp.sudosu.fyi`) and whether it's behind Caddy.

If behind Caddy, check the subdomain mapping:
```bash
sudo grep -A3 '<appname>' /etc/caddy/Caddyfile /etc/caddy/apps.caddy 2>/dev/null
```

**For apps that listen on a port but don't have a Caddy subdomain yet:**
- Set `endpoint` to `null` (no public URL yet)
- Set `subdomain` to `null`
- Still set `port` to the internal port — agents need this for health checks and access via Tailscale IP

**For apps with no web interface** (background workers, CLI tools):
- Omit the entire access section or set all fields to `null`

### 4. Classify the app (on Mac)

Choose a category:

| Category | Examples |
|----------|---------|
| infra | Caddy, authelia, LLDAP, DNS |
| service | Outline, Gitea, Nextcloud |
| monitoring | Uptime Kuma, Dozzle, Grafana |
| project | Research-specific deployments (ais_app, seascan) |
| personal | Jellyfin, Plex, personal tools |

Choose auth method: `none`, `tailscale`, `authelia`, `basic`, or `custom`.

### 5. Fill the template (on Mac)

Copy `templates/app_entry.yaml` and fill in:

**For simple (single-service) apps:**
- Fill identity, access, deployment, status fields directly
- Set `port` and `health_check` at the top level

**For multi-container apps** (compose with web + db + cache, etc.):
- Remove the top-level `port` and `health_check` fields
- Add a `services` block listing each container:

```yaml
services:
  - name: "web"              # compose service name
    role: primary             # primary | worker | database | cache | sidecar
    port: 3000
    health_check: "/health"
  - name: "postgres"
    role: database
    port: 5432
  - name: "redis"
    role: cache
    port: 6379
```

Exactly one service must have `role: primary` — that service's port and health_check are used for routing and monitoring.

**For all apps:**
- Set `depends_on` if the app needs other registered apps (informational only)
- Set `repo` if the source code is registered in `repos.yaml`
- Set `added` and `last_verified` to today

### 6. Add to registry (on Mac)

Insert the filled entry into `registry/apps.yaml` under the `apps:` key.

If this is the first entry, replace `apps: {}` with:
```yaml
apps:
  <your_entry_here>
```

### 7. Commit and push (on Mac)

```bash
git add registry/apps.yaml
git commit -m "Register app: <app_name> on <server_name>"
git push
```

## Verification

After registration, confirm:

- [ ] Entry has no `<PLACEHOLDER>` values remaining
- [ ] Server referenced in `server` field exists in `servers.yaml`
- [ ] If web app: endpoint is reachable from Tailscale network
- [ ] If health_check set: health endpoint returns 200
- [ ] YAML is valid: `uv run --with pyyaml python3 -c "import yaml; yaml.safe_load(open('registry/apps.yaml')); print('Valid')"`

## Decision guide: what to register

Not every running process needs to be in the registry. Register an app if:

- It's a **service you care about** — you'd want to know if it goes down
- It has a **web interface** or **API** that other things consume
- It's **infrastructure** that other apps depend on (auth, proxy, database)
- An agent might need to **deploy, restart, or check** it

Skip registration for:
- System services (cron, ssh, NetworkManager)
- One-off experiments or temporary containers
- Legacy/unused services the user confirms are not needed
- Services you plan to remove soon

**When in doubt, ask the user.** During initial server onboarding, present the full list of discovered services and let the user decide what's worth registering. This is a one-time judgment call.

## The registry rule

**After a server is onboarded, all new apps deployed to it must be registered via this protocol. If an app is not in the registry, it does not exist.** This ensures the registry stays complete and agents can trust it as the source of truth.

## Notes

- **One app = one registry entry**, even if it has multiple containers. The compose file groups them; the registry tracks the app as a unit.
- **Dependencies** (`depends_on`) are informational — they help agents understand the dependency graph but don't enforce startup order.
- **Repos:** If the app's source code is a registered repo, link them via the `repo` field. The deployment relationship (which server, which app) lives here in apps.yaml, not in repos.yaml.
- **Internal compose dependencies** (e.g., an app's own Postgres or Redis) are part of the app, not separate registry entries. Only register standalone shared databases as separate apps.
