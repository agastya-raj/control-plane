# control-plane

Personal infrastructure mesh — unified registry of servers, apps, repos synced across all Tailscale-connected servers.

## Quick Start
- Read `infra.md` for the infrastructure knowledge hub (registry, protocols, conventions)
- Read `VISION.md` for the full architecture and phases
- Deploy target: `~/.stack/infra/` on every server (set up by `install.sh` — symlink on Mac, clone on remote servers)
- Mac is primary writer, GitHub is hub, servers cron-pull
- **Prefer protocols when available** — `protocols/` has step-by-step guides for registration and onboarding
- Read `registry/` YAML files for current server/app/repo state
