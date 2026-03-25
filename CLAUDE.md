# control-plane

Personal infrastructure mesh — unified registry of servers, apps, repos synced across all Tailscale-connected servers.

## Quick Start
- Read `infra.md` for the infrastructure knowledge hub (registry, protocols, conventions)
- Read `VISION.md` for the full architecture and phases
- This repo lives at `~/.agastya/` on every server
- Mac is primary writer, GitHub is hub, servers cron-pull
- **Don't install or configure servers directly** — use the protocols in `protocols/`

## Symphony Orchestration Rules

This project is managed by Symphony (scale: **small**). Read `SYMPHONY.md` for project config.

### Execution Rules
- Use **plain agents** for feature work. Teams only if agents need to coordinate.
- **Do NOT use worktrees** — work directly on branches. Worktrees add overhead at small scale.
- Small fixes (< 20 lines, single file): implement directly.
- Batch related work together — one branch and one PR per batch.
- **Always commit your work.** Symphony hooks auto-push and create PRs only if commits exist.

### Branch & PR Conventions
- Branch naming: `symphony/<batch-name>` (e.g., `symphony/processing-pipeline`)
- Push branch when ready. PR body should reference relevant Linear issue identifiers.
- **No per-PR Codex reviews at small scale.** The cron reviewer skips small-scale projects.

### Quality Gate: Milestone Dual Review
- Before any **release**, **epic closure**, or **major feature merge**: run `/dual-review`.
- This is the ONLY review gate at small scale. It is mandatory. Both Claude and Codex must review.
- Fix all HIGH findings before proceeding. MEDIUM: fix or explicitly accept.
- Do NOT skip this. Per-PR reviews are skipped precisely because this gate exists.

### Linear Integration
- Linear syncs automatically (PR→In Progress, merge→Done).
- Check Linear for prioritized work before starting.

### Quality Standards
- Follow patterns declared in SYMPHONY.md `patterns` section.
- Ensure tests exist for new functionality.

### Agent Discovery
- Read `docs/contracts.md` for all public interfaces before implementing.
- Read module `__init__.py` files for the API surface of each package.
- Read `tests/conftest.py` for available test fixtures and patterns.
- Check `### Module Dependencies` below for which modules to read for context.
