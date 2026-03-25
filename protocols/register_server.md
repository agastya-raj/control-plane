# Protocol: Register a Server

Add a server and its confirmed apps to the control-plane registry.

**Prerequisites:**
1. Server provisioned (`protocols/provision_server.md`)
2. Discovery report generated (`protocols/discover_server.md`)
3. User has reviewed the report and decided which apps/repos to register

**This protocol takes confirmed decisions as input.** All edits happen on Mac. Passwordless sudo is available on all servers if you need to re-check anything.

## Inputs

Before starting, you need:
- The **discovery report** from `protocols/discover_server.md`
- The user's decisions: which apps to register, which repos to register

## Steps

### 1. Fill the server template (on Mac)

Copy `templates/server_entry.yaml` and fill in from the discovery report:

- Replace all `<PLACEHOLDER>` values with data from the report
- Set `roles` based on what the server is used for:

| Role | When to assign |
|------|---------------|
| compute | Has GPU or is used for heavy computation / ML |
| homelab | Runs self-hosted services (wiki, git, monitoring, etc.) |
| testbed | Used for research experiments |
| dev | Primary development machine |
| media | Runs media services (Plex, Jellyfin, etc.) |
| sandbox | Sandboxed/isolated execution environment |

Roles are extensible — add custom ones if needed (e.g., `hpc`, `storage`).

- Set `capabilities` (only confirmed ones from the report)
- Fill `hardware` block (use `null` for unknowns)
- Add services that the user confirmed as actively used
- Set `gateway` if this server is only reachable through another server
- Set `domain` if it serves web traffic
- Set `added` and `last_audit` to today's date

### 2. Register confirmed apps (on Mac)

For each app the user confirmed, follow `protocols/register_app.md`:
- Use data from the discovery report (ports, compose paths, status)
- Fill `templates/app_entry.yaml` for each app

During initial onboarding, it's normal to register multiple apps in one batch. The per-app protocol (`register_app.md`) is for subsequent individual deployments.

### 3. Register confirmed repos (on Mac)

For each repo the user confirmed, fill `templates/repo_entry.yaml`:
- Use paths from the discovery report
- Set `language`, `category`, `status`

If a repo is also a deployed app, make sure **both** the repo entry (repos.yaml) and app entry (apps.yaml) exist.

### 4. Add to registries (on Mac)

Insert entries into the registry files under their respective keys:
- Server → `registry/servers.yaml` under `servers:`
- Apps → `registry/apps.yaml` under `apps:`
- Repos → `registry/repos.yaml` under `repos:`

If this is the first entry in a file, replace the `{}` with a newline:
```yaml
servers:
  <your_entry_here>
```

### 5. Validate

```bash
uv run --with pyyaml python3 -c "
import yaml
for f in ['registry/servers.yaml', 'registry/apps.yaml', 'registry/repos.yaml']:
    data = yaml.safe_load(open(f))
    key = f.split('/')[1].split('.')[0]
    entries = data.get(key, {})
    print(f'{f}: {len(entries)} entries — {list(entries.keys())}')
"
```

Also confirm:
- [ ] No `<PLACEHOLDER>` values remain
- [ ] SSH alias works: `ssh <ssh_alias> hostname`
- [ ] Server key in app entries exists in servers.yaml

### 6. Commit and push (on Mac)

```bash
git add registry/servers.yaml registry/apps.yaml registry/repos.yaml
git commit -m "Register server: <server_name>"
git push
```

## Notes

- **Mac is the primary writer.** All edits happen on Mac. Other servers are read-only and pull via cron.
- **Gateway servers:** If the server is behind another server (e.g., `turing` reachable only from `gpu`), set `gateway: gpu`. Only single-hop gateways are supported currently.
- **Re-auditing:** To update an existing server, re-run `discover_server.md` and update entries. Set `last_audit` to today.
- **After onboarding:** All new apps deployed to this server **must** be registered via `protocols/register_app.md`. If it's not in the registry, it doesn't exist.
