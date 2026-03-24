# control-plane

Personal infrastructure mesh — unified registry of servers, apps, repos synced across all Tailscale-connected servers.

## Quick Start
- Read VISION.md for the full architecture and phases
- This repo will live at ~/.agastya/ on every server
- Mac is primary writer, GitHub is hub, servers cron-pull

## Structure (target)
```
registry/         ← servers.yaml, apps.yaml, repos.yaml
protocols/        ← deploy.md, register_app.md, etc.
handoffs/         ← active/completed compute handoff docs
secrets/          ← age-encrypted secrets (gitignored values)
skills/           ← Claude Code skills (symlinked on each server)
sync/             ← install.sh, health_check.sh
templates/        ← app/server/compose templates
claude/           ← shared Claude Code config
```

## Conventions
- YAML for all registry files
- Markdown for all protocol docs
- snake_case naming
- Docker Compose as deploy standard
- Every registry change gets a descriptive commit message
