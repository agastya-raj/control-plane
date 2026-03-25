# Control Plane — Full Vision

*A personal infrastructure mesh that gives any agent on any server instant awareness of the entire ecosystem.*

## Origin Story

Started by exploring the A2A (Agent-to-Agent) protocol for delegating work between local Mac and a GPU server. Concluded that A2A was overkill — the real need wasn't inter-agent protocol, but **reducing friction in remote compute, deployment, and cross-server awareness**.

Built compute-bridge (MCP server for SSH-based remote execution) as the transport layer. During testing, discovered the deeper problem: agents have no idea what infrastructure exists, what's running where, how to deploy, or how to hand off work. Every session starts from scratch.

## The Problem

| Pain | Example |
|------|---------|
| No central view | "What's running on GPU?" → ssh in, check docker ps, check systemd, check tmux... |
| Ad-hoc deployment | Each app deployed differently, no standard, forgotten after a while |
| Agent blindness | Claude Code on Mac doesn't know about GPU capabilities, testbed servers, running services |
| Lost context | Work done on one server is invisible to agents on other servers |
| No handoff protocol | "Run this overnight on GPU" → manual SSH, no structured way to resume |
| Scattered secrets | API keys in .env files on random servers, no inventory |
| No change awareness | "What happened since yesterday?" → no answer without manual investigation |

## The 4-Layer Architecture

```
┌─────────────────────────────────────────────────┐
│  Knowledge Layer (WHY)                           │
│  ~/.stack/knowledge/                             │
│  Research context, architecture decisions,        │
│  lessons learned. Full clone on all servers.      │
├─────────────────────────────────────────────────┤
│  Project Layer (WHAT)                            │
│  ~/.stack/symphony/                              │
│  Planning, PR workflow, code review, Linear sync. │
│  Runs on all servers with Claude Code.            │
├─────────────────────────────────────────────────┤
│  Infrastructure Layer (WHERE/HOW)                │
│  ~/.stack/infra/                                 │
│  Server/app/repo registry, deploy protocols,      │
│  handoff docs, secrets, sync. Git-backed.         │
├─────────────────────────────────────────────────┤
│  Transport Layer (DO)                            │
│  ~/.stack/transport/                             │
│  Remote execution, file transfer, background      │
│  tasks. 16 tools, SSH-based.                      │
└─────────────────────────────────────────────────┘
```

**Flow:** Knowledge tells agents *why*. Symphony tells them *what* to build. Control-plane tells them *where* things run and *how* to deploy. Compute-bridge *does* the remote execution.

### Layer Entry Points

Each layer has a single discoverable entry-point document that gives agents instant context. These are referenced from `~/.claude/CLAUDE.md` (global agent instructions), creating a connected knowledge graph:

| Layer | Path | Entry-point | Purpose |
|-------|------|------------|---------|
| Infrastructure | `~/.stack/infra/` | `infra.md` | Registry structure, protocols, conventions, common tasks |
| Project | `~/.stack/symphony/` | `SYMPHONY.md` (per-project) | Orchestration config, scale, review patterns |
| Knowledge | `~/.stack/knowledge/` | TBD | Knowledge base structure, how to search/capture/curate |
| Transport | `~/.stack/transport/` | TBD | Available tools, server config, transport options |

Each entry-point doc answers: what is this layer, why does it exist, where are things, and how do I use it. An agent reads CLAUDE.md → discovers all layers → reads the relevant doc → knows what's available.

## What Already Exists

### compute-bridge ✅ (built, tested, committed)
- Currently at ~/code/compute-bridge (target: ~/.stack/transport/)
- MCP server with 16 tools
- Remote shim auto-deployed to servers (stdlib-only, Python 3.8+)
- Structured JSON envelopes for all responses
- Background task management (start/status/logs/stop)
- File push/pull, project scaffolding, server health
- Config at ~/.config/compute-bridge/config.yaml (target: ~/.stack/transport/config.yaml)
- 79 unit tests + 3 E2E tests passing
- Opt-in via disabledMcpjsonServers toggle
- Dual-reviewed (Claude + Codex), all HIGH/MEDIUM findings fixed

### custom_domain ✅ (built, on GPU server)
- Vapor (Swift) app at dash.sudosu.fyi
- Caddy reverse proxy for *.sudosu.fyi wildcard
- YAML-backed app registry with CRUD API
- Tile-based dashboard UI
- Tailscale-only access
- Will be extended as the status hub (Phase 4)

### Symphony ✅ (built, running on Mac)
- Currently at ~/.symphony/ (target: ~/.stack/symphony/)
- Dev orchestration: planning, PR creation, code review, Linear sync
- Cron-based Codex reviews, tech debt scanning
- Session hooks for Claude Code
- Scale-aware policies (small/medium/large)
- To be deployed on all servers (future phase)

### knowledge_framework ✅ (exists, needs integration)
- Currently at ~/ad_hoc/knowledge_framework (target: ~/.stack/knowledge/)
- Captures research context, architecture decisions, lessons learned
- Currently Mac + GitHub only
- To be cloned on all servers (future phase)

## Current Server Inventory

| Server | SSH Alias | Role | Key Services | Status |
|--------|-----------|------|-------------|--------|
| Mac (local) | — | Primary dev, orchestration | Symphony, compute-bridge | Active |
| GPU workstation | gpu | Compute, homelab services | custom_domain, Caddy, Docker apps | Active |
| Open Ireland OL2 | ol2 | Testbed | Optical experiments | Active |
| Open Ireland OL4 | ol4 | Testbed, telemetry | Grafana dashboards, Kafka | Active |
| Mini PC | minipc | General | Various | Often offline |
| Tian's PC | tianpc | General | Various | Often offline |
| Claude server | claude | Sandbox compute | Sandboxed execution | Available |
| Home server | home | Media | Plex | Active |

All connected via Tailscale.

---

## Implementation Phases (revised)

### Phase 1: Foundation
**Goal:** Any agent on any server is instantly oriented — knows all servers, apps, repos, and how to reach them.

**Deliverables:**
- Git repo for control-plane, GitHub-backed (github.com/agastya/control-plane)
- Registry schemas and entry templates (servers, apps, repos)
- Registration protocols (provision, discover, register)
- CLAUDE.md + infra.md — agent entry points
- Two servers onboarded (GPU, claude-server) as protocol validation

*Note: sync mechanism (install.sh, cron), ET, and ~/.stack/ deployment moved to Phase 3.*
- Claude Code config sync:
  - ~/.stack/infra/CLAUDE.md symlinked to ~/.claude/CLAUDE.md on each server
  - Shared skills directory (empty for now, populated in Phase 3)
- Initial population: audit Mac + GPU for all current servers/apps/repos

**Verification:**
- Clone on Mac and GPU, cron sync working
- Agent on GPU reads CLAUDE.md, can answer "what apps are on this server?"
- Agent on Mac can answer "what servers have GPUs?"
- ET sessions work between Mac ↔ GPU

---

### Phase 2: Protocols + Deploy Standard
**Goal:** Standardized, documented processes for deploying apps and onboarding servers.

**Deliverables:**
- Protocol documents:
  - deploy.md — standard deploy process (Docker Compose baseline)
  - register_app.md — how to add a new app to the registry
  - register_server.md — how to onboard a new server (incl. ET, sync, Claude Code)
  - agent_orientation.md — what to do first when landing on a new server
- Docker Compose standardization:
  - Template docker-compose.yml + Dockerfile
  - Convention: every app has a Dockerfile + compose file
  - Health check endpoint required (/health)
- apps.yaml → custom_domain cascade:
  - Define how registry updates propagate to Caddy config
  - New app registered → subdomain auto-routed

**Verification:**
- Deploy custom_domain using the standard protocol
- Register a new test app following register_app.md
- Verify apps.yaml updated and Caddy routes the new subdomain

---

### Phase 3: Skills + Session Briefing
**Goal:** Agents can act on the registry (not just read it) and are briefed on changes each session.

**Deliverables:**
- Claude Code skills (in ~/.stack/infra/skills/, symlinked to ~/.claude/skills/):
  - /register-app — interactive skill to register a new app
  - /deploy — deploy an app to its target server
  - /server-status — quick check of a server's health + running apps
- Session-start hook on every server:
  - cd ~/.stack/infra && git pull
  - Show registry changes in last 24h
  - Show active handoffs
  - Show server health summary
- Changelog mechanism:
  - git log-based (structured commit messages)
  - Session briefing parses recent commits
- Integration with Symphony session hooks (compose, don't duplicate)

**Verification:**
- Register a new app using /register-app skill on Mac
- Start session on GPU — briefing shows "1 new app registered"
- Run /server-status gpu — see health + running apps

---

### Phase 4: Compute Handoff
**Goal:** Structured way to hand off long-running work between servers, with checkpoint docs for context preservation.

**Deliverables:**
- Handoff protocol doc (protocols/compute_handoff.md)
- Handoff skill: /handoff — creates handoff doc, sets up remote env, starts task
- Handoff document schema:
  - Objective, configuration, progress, how to resume, decision log
  - Status tracking: running → completed/paused/failed
  - Auto-commits status changes to the registry
- Resume skill: /resume-handoff <id> — reads handoff doc, orients agent
- Integration with compute-bridge:
  - task_start creates handoff entry
  - task_status updates handoff progress
  - Completion triggers handoff status update + git commit
- Knowledge framework pointer: handoff docs reference relevant knowledge entries

**Verification:**
- Hand off an HPO sweep from Mac to GPU
- Check handoff status from Mac (without SSH-ing to GPU)
- Resume the handoff on GPU the next day — agent knows full context

---

### Phase 5: Secrets + Security
**Goal:** API keys and credentials managed securely across all servers, no more scattered .env files.

**Deliverables:**
- age encryption setup:
  - Public key in ~/.stack/infra/secrets/keys/age.pub (in git)
  - Private key at ~/.age/key.txt on each server (not in git, one-time setup)
- Secrets schema:
  - secrets.yaml — declares what each app/server needs (in git, no values)
  - <server>.env.age — encrypted env files per server (in git, safe)
- Decrypt-on-deploy: deploy protocol decrypts secrets before starting containers
- Secret rotation: update encrypted file, commit, servers pull + redeploy
- Integration with compute-bridge: forward_env reads from decrypted secrets

**Verification:**
- Encrypt GPU secrets, commit to repo
- Deploy an app on GPU that needs HF_TOKEN — verify it's decrypted correctly
- Rotate a secret, verify all servers pick up the change

---

### Phase 6: Status Hub
**Goal:** Single dashboard for infrastructure state, live health, and notifications.

**Deliverables:**
- Extend custom_domain Vapor app with:
  - /status — live server health, running tasks, active handoffs
  - /changelog — recent registry changes, deploys, handoff completions
  - /api/notify — POST endpoint for servers to push events
- Server health polling:
  - Periodic health checks of all registered servers (via compute-bridge shim)
  - Visual status indicators (green/yellow/red)
- Notification aggregation:
  - Task completion, deploy success/failure, handoff status changes
  - Optional: ntfy.sh push notifications for critical events
- Mobile-friendly: accessible from iPhone via Safari (already PWA-capable)

**Verification:**
- Open dash.sudosu.fyi/status — see all servers and their health
- Deploy an app — see it appear in /changelog
- Complete a handoff — see notification in /status

---

### Phase 7: Integrations
**Goal:** All existing systems read from the control-plane as their shared source of truth.

**Deliverables:**
- compute-bridge integration:
  - Reads servers.yaml from ~/.stack/infra/registry/ (replaces its own config)
  - server_add writes to control-plane registry
  - Capability matching: "find a server with GPU and 20GB free VRAM"
  - Optional ET transport for long sessions
- Symphony on all servers:
  - Install on GPU + testbed servers
  - Shared Symphony config synced via control-plane
  - Cross-server project visibility
  - Post-merge hook triggers deploy via control-plane protocol
- Knowledge framework:
  - Clone to all servers via same cron sync
  - Agent orientation includes "check knowledge base for project context"
  - Session briefing includes recent knowledge entries
  - Handoff docs reference knowledge entries

**Verification:**
- Add a server via control-plane → compute-bridge immediately sees it
- Start a Symphony project on GPU → visible from Mac dashboard
- Create a knowledge entry on Mac → readable on GPU next session

---

### Phase 8: Monitoring + Resilience
**Goal:** Know when things break, before you have to check manually.

**Deliverables:**
- health_check.sh on every server (cron, hourly):
  - Checks: disk space, Docker running, key services alive, sync freshness
  - Writes results to ~/.stack/infra/health/<server>.yaml
  - Pushes to status hub /api/notify on failure
- ntfy.sh integration:
  - Self-hosted or public ntfy.sh endpoint
  - Critical alerts: server down, disk >90%, service crash
  - iPhone notifications via ntfy app
- Backup conventions:
  - apps.yaml has per-app backup field (type, path, schedule)
  - Backup protocol doc
  - restic or borg to a backup target (e.g., home server)
- Second-hop server support:
  - Gateway field in servers.yaml for multi-hop access
  - compute-bridge ProxyJump support for testbed internal nodes

**Verification:**
- Take a Docker service down on GPU → notification on phone within minutes
- Run health_check on all servers → aggregated view on status hub
- Backup a service's data → verify restore works

---

## Design Principles

1. **Git is the source of truth** — everything auditable, versionable, works offline
2. **Mac is primary, GitHub is hub** — conflict-free sync via pull-only on servers
3. **Docker Compose is the deploy standard** — one way to deploy, everywhere
4. **CLAUDE.md is the agent entry point** — read this, know everything
5. **Protocols over automation** — documented processes first, skills/automation second
6. **Tailscale is the network** — all servers connected, no public exposure
7. **Extend, don't rebuild** — custom_domain becomes status hub, compute-bridge reads from registry
8. **Incremental delivery** — each phase is independently useful

## Network Topology

```
                    ┌──────────┐
                    │  GitHub  │ ← hub for git sync
                    └────┬─────┘
                         │
    ┌────────────────────┼────────────────────┐
    │                    │                    │
┌───┴───┐          ┌────┴────┐          ┌────┴────┐
│  Mac  │──────────│   GPU   │──────────│  ol2/4  │
│primary│ Tailscale│ services│ Tailscale│ testbed │
└───┬───┘          └────┬────┘          └─────────┘
    │                   │
    │              ┌────┴────┐
    │              │  Caddy  │
    │              │*.sudosu │
    │              │  .fyi   │
    │              └─────────┘
    │
┌───┴────────┐
│ compute-   │
│ bridge MCP │
│ (16 tools) │
└────────────┘
```

## File Structure (final vision)

```
~/.stack/infra/                              ← git repo, synced everywhere
├── CLAUDE.md                            ← agent entry point
├── registry/
│   ├── servers.yaml                     ← all servers
│   ├── apps.yaml                        ← all deployed apps
│   └── repos.yaml                       ← all repos
├── protocols/
│   ├── deploy.md                        ← Docker Compose deploy standard
│   ├── register_app.md                  ← how to register a new app
│   ├── register_server.md               ← how to onboard a new server
│   ├── compute_handoff.md               ← how to hand off compute
│   └── agent_orientation.md             ← first time on a server
├── handoffs/
│   └── <id>.md                          ← active/completed handoff docs
├── secrets/
│   ├── secrets.yaml                     ← what each app needs (no values)
│   ├── gpu.env.age                      ← encrypted secrets per server
│   └── keys/age.pub                     ← public encryption key
├── skills/
│   ├── register-app/                    ← Claude Code skill
│   ├── deploy/                          ← Claude Code skill
│   └── handoff/                         ← Claude Code skill
├── sync/
│   ├── install.sh                       ← onboard a new server
│   └── health_check.sh                  ← verify sync working
├── templates/
│   ├── app_entry.yaml                   ← template for new app
│   ├── server_entry.yaml                ← template for new server
│   ├── docker-compose.template.yml      ← starter compose file
│   └── Dockerfile.template              ← starter Dockerfile
└── changelog.yaml                       ← structured change log
```

---

## Missing Pieces (added during review)

### Eternal Terminal (ET) for Persistent Sessions

SSH sessions drop on network changes, sleep, or roaming. Eternal Terminal (ET) maintains persistent, low-latency sessions that survive all of this.

**How it fits:**
- ET daemon runs on every server (installed during server onboarding)
- compute-bridge gains an `et` transport option alongside `ssh` (future)
- For agent handoffs: the receiving agent connects via ET, which is already alive — no connection setup latency
- Long-running interactive sessions (debugging on GPU, tailing logs) use ET instead of SSH

**Implementation:**
- Phase 1: Install ET on GPU + Mac as part of server onboarding
- Phase 2: compute-bridge optionally uses `et` instead of `ssh` for long sessions
- Convention: `et <server>` should Just Work for all registered servers

### Claude Code Configuration Sync

Not all Claude Code config should sync — but the essentials should be consistent across servers.

**What syncs (via ~/.stack/infra/):**
```
~/.stack/infra/
├── CLAUDE.md                    ← agent entry point (symlinked to ~/.claude/CLAUDE.md)
├── infra.md                     ← infrastructure knowledge hub
├── skills/                      ← shared skills (deploy, register, handoff)
├── registry/                    ← servers, apps, repos
├── protocols/                   ← onboarding, registration, deploy
└── templates/                   ← entry templates
```

**What stays local (NOT synced):**
- MCP server registrations (server-specific)
- Hooks (Symphony hooks only on Mac, others vary)
- Session state, conversation history
- Plugin configs

**Sync mechanism:** On server onboarding, `install.sh` creates symlinks:
```bash
ln -sf ~/.stack/infra/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf ~/.stack/infra/skills/* ~/.claude/skills/
```

### apps.yaml ↔ custom_domain Sync

The control-plane `apps.yaml` and custom_domain's `apps.yaml` are two registries that should be one.

**Resolution:** control-plane's `apps.yaml` is the source of truth. custom_domain reads from it (or a sync job writes control-plane → custom_domain format). When an agent registers a new app via the protocol:
1. Updates `~/.stack/infra/registry/apps.yaml`
2. Commits + pushes
3. GPU pulls → custom_domain picks up → Caddy reloads → subdomain live

### GPU Server's Internal Network

The GPU server itself has SSH access to other machines (turing, oi_gateway, ona, ona_server, etc. — TCD research infrastructure). These are "second-hop" servers not directly reachable from Mac.

**How it fits:**
- servers.yaml has a `gateway` field for multi-hop access:
  ```yaml
  turing:
    ssh_alias: turing
    gateway: gpu              # reach via gpu server
    roles: [hpc]
    notes: "TCD HPC cluster, accessible from GPU only"
  ```
- compute-bridge could support ProxyJump for second-hop servers
- Agent orientation: "to reach turing, you need to be on gpu first"

### Monitoring & Alerting

Beyond the status hub dashboard, there should be basic awareness of failures.

**Lightweight approach:**
- health_check.sh runs on every server via cron (hourly)
- Checks: disk space, Docker running, key services alive, sync freshness
- If a check fails: writes to ~/.stack/infra/health/<server>.yaml
- Status hub (custom_domain) aggregates health files
- Optional: push notification via ntfy.sh (self-hosted or public) for critical failures

### Backup Strategy

The registry is in git (safe). But app data isn't.

**Convention per app:**
- apps.yaml has a `backup` field:
  ```yaml
  custom-domain:
    backup:
      type: volume
      path: /var/lib/custom-domain/data
      schedule: daily
  ```
- A backup protocol doc covers the standard: restic/borg to a backup target
- Not Phase 1, but worth documenting the intent

---

## Future Work / Explorations

These are ideas to explore later — not committed to any phase.

### A2A Protocol (if this grows beyond personal use)
The original inspiration. If collaborators or other researchers need to use your infrastructure, the control-plane registries + protocols could be exposed as A2A Agent Cards. Each server becomes a discoverable agent with declared capabilities. Unlikely to be needed soon, but the registry design is already compatible.

### Lightweight Container Orchestration
If Docker Compose per-app becomes limiting (e.g., apps that need to move between servers, auto-restart on failure, resource limits), consider Docker Swarm (simplest) or Nomad (more capable, still simple). The deploy protocol would wrap these instead of bare `docker compose up`.

### Infrastructure as Code
For reproducible server setup: an Ansible playbook per server role that installs ET, Docker, the sync cron, Claude Code, etc. Run it on a fresh server → it's fully onboarded. Currently manual via `install.sh`, but Ansible is the natural next step.

### Unified Observability
All servers ship logs/metrics to a central stack:
- Logs: Loki (or just structured files synced to a log server)
- Metrics: Prometheus + existing Grafana on ol4
- Traces: OpenTelemetry (if running distributed experiments)
- The control-plane status hub becomes the entry point to all of this

### Cross-Server Experiments
Optical network experiments that span ol2 + ol4 (or more nodes). The control-plane could track experiment state:
```yaml
experiments:
  ofc_2026_demo:
    servers: [ol2, ol4]
    status: running
    started: 2026-03-20
    handoff: experiments/ofc-2026.md
```
This is a specialization of the handoff protocol for multi-server coordination.

### Mobile Dashboard & Notifications
The custom_domain dashboard is already PWA-capable. Extend with:
- Push notifications (via ntfy.sh or web push API)
- Quick actions from phone (restart a service, check handoff status)
- Apple Shortcuts integration (Siri: "what's running on GPU?")

### Research Data Management
Experiment results, datasets, model checkpoints — these are large files that don't belong in git. Convention:
- Each server has a `~/data/` directory
- repos.yaml tracks which datasets live where
- DVC (Data Version Control) or just rsync conventions for moving large files
- The registry tracks what data exists where, even if it can't sync it

### Agent Autonomy Levels
Not all tasks need the same level of agent involvement:
- **Level 0: Fire and forget** — task_start, check later
- **Level 1: Checkpoint** — agent runs, writes handoff doc at milestones
- **Level 2: Supervised** — agent makes decisions but logs everything for review
- **Level 3: Autonomous** — agent plans, executes, deploys, reports results
The handoff protocol could specify the autonomy level per task.

### Repo Documentation Standards
Every repo in the ecosystem should have a standard set of documentation files that give agents and humans instant context. The control-plane's CLAUDE.md should instruct agents to create/maintain these when working on any registered repo:

- **VISION.md** — what this project is, why it exists, where it's going (the "north star")
- **DESIGN.md** — architecture, key decisions, data flow, component relationships (the "how")
- **CHANGELOG.md** — structured log of significant changes (complements git log with context)
- **CONVENTIONS.md** — project-specific patterns, naming rules, testing approach (the "style guide")
- **STATUS.md** — current state, known issues, what's in progress (the "pulse")

Not every repo needs all of these — small tools might only need VISION.md and DESIGN.md. The registration protocol should assess which docs are appropriate based on repo size and category. Agents should be able to generate initial drafts of these from code analysis and git history.

### GPU Server Cleanup
The GPU server has accumulated many legacy Docker containers and systemd services over time with no clear record of what's active vs abandoned. After the control-plane is operational, a dedicated cleanup pass is needed:
- Audit all running services against the registry
- For each unregistered service, ask the user: keep and register, or decommission?
- Stop and remove decommissioned containers/services
- Clean up Caddy placeholder routes (grafana, jellyfin, hass, portainer) that point to non-existent or other servers
- This is a concrete example of why the control-plane exists — infrastructure amnesia

---

## Success Criteria

The control-plane is "done" when:

1. **Any agent, any server, instant orientation** — reads CLAUDE.md, knows everything
2. **"What's running on X?"** — one command, accurate answer
3. **"Deploy Y to Z"** — follows standard protocol, works every time
4. **"Run this overnight"** — structured handoff, easy resume
5. **New server in 15 minutes** — run install.sh, synced and ready
6. **New app in 5 minutes** — Dockerfile, register, deploy, subdomain live
7. **No more "I forgot"** — everything is in the registry or it doesn't exist
