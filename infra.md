# Infrastructure Knowledge Hub

This repo (`control-plane`) is the central registry for a personal infrastructure mesh. It lives at `~/.agastya/` on every server and provides instant awareness of the entire ecosystem.

## What's here

```
registry/
  servers.yaml     All servers — how to reach them, capabilities, hardware
  apps.yaml        All deployed apps — endpoints, deploy method, health checks
  repos.yaml       All repos — GitHub URLs, local paths per server

protocols/
  discover_server.md   Automated server audit — produces a discovery report
  register_server.md   Register a server + confirmed apps/repos from the report
  register_app.md      Register an individual app (post-onboarding)
  agent_orientation.md What to do first on any server

templates/
  server_entry.yaml    Starter template for new server entries
  app_entry.yaml       Starter template for new app entries
  repo_entry.yaml      Starter template for new repo entries
```

## How it works

- **Mac is the primary writer.** All edits to the registry happen on Mac and push to GitHub.
- **GitHub is the hub.** Servers pull changes via cron (every 5 min).
- **Servers are read-only.** They never push — this prevents conflicts.
- **Git is the source of truth.** Everything is auditable, versionable, works offline.
- **The registry is the law.** If an app or server is not in the registry, it does not exist. All new deployments must be registered via the protocols.

## Registry overview

### Servers (`registry/servers.yaml`)

Every server in the Tailscale mesh is registered with:
- Identity: hostname, SSH alias, Tailscale IP, user
- Roles: compute, homelab, testbed, dev, media, sandbox (extensible)
- Capabilities: gpu, docker, caddy, ollama, etc. — flat list for querying
- Hardware: CPU, RAM, disk, GPU specs
- Services: what's expected to be running (for health checks)

Query example: "find a server with GPU" → scan capabilities lists.

### Apps (`registry/apps.yaml`)

Every deployed application is registered with:
- Where it runs (server key → links to servers.yaml)
- How to reach it (endpoint, subdomain, port)
- How it's deployed (docker-compose, systemd, binary, manual)
- Multi-container support via `services` list with roles
- Dependencies on other apps (informational)

Apps.yaml is the single source of truth for deployment mapping.

### Repos (`registry/repos.yaml`)

Every important repo is tracked with:
- GitHub URL and local clone paths per server
- Language and category (infra, research, tools, personal)

Repos.yaml tracks where code lives. Deployment info (which server, which app) lives in apps.yaml.

## Conventions

- **YAML** for all registry files
- **Markdown** for all protocols and docs
- **snake_case** for file names, YAML keys, server/app names
- **Docker Compose** as the deploy standard
- **Absolute paths** in all registry fields (no `~` expansion)
- **Descriptive commit messages** for every registry change

## Common tasks

| I want to... | Do this |
|--------------|---------|
| Onboard a new server | Run `protocols/discover_server.md`, review report with user, then `protocols/register_server.md` |
| Register an app | Follow `protocols/register_app.md` |
| Orient on a server | Follow `protocols/agent_orientation.md` |
| Find what's on a server | Read `registry/apps.yaml`, find entries where `server: "<name>"` |
| Find a server with GPU | Read `registry/servers.yaml`, check `capabilities` lists for `gpu` |
| Check a repo's location | Look up the repo key in `registry/repos.yaml` → `local_paths` |

## Architecture context

This repo is one layer of a 4-layer stack:

| Layer | Repo | Purpose |
|-------|------|---------|
| Knowledge | `~/ad_hoc/knowledge_framework` | Research context, architecture decisions, lessons learned |
| Project | Symphony (`~/.symphony/`) | Planning, PR workflow, code review, Linear sync |
| **Infrastructure** | **`~/.agastya/` (this repo)** | **Server/app/repo registry, protocols, sync** |
| Transport | `~/code/compute-bridge` | Remote execution via SSH (16 MCP tools) |

See `VISION.md` for the full architecture, phases, and future plans.
