---
project:
  name: control-plane
  repo: agastya-raj/control-plane
  linear_project: 7614e3d73f28
  language: unknown
orchestration:
  scale: small
  review_label: symphony
  branch_prefix: symphony/
  auto_merge: false
review:
  enabled: true
  domains:
  - quality
  - security
  - docs
  - tests
  - architecture
  model: gpt-5.4
  poll_interval_minutes: 15
tech_debt:
  enabled: true
  scan_schedule: daily
  max_issues_per_scan: 5
patterns:
  patterns: []
  exclude:
  - .venv/
  - __pycache__/
  - '*.pyc'
  - node_modules/
design:
  style: ''
  colors: ''
  target_user: ''
validation:
  required: []
  recommended: []
review_patterns:
  patterns:
  - Error handling must be explicit — no silent failures
  - Input validation at system boundaries
assumptions:
  assumptions:
  - Standard development toolchain for this language
---

Personal infrastructure mesh — unified registry of servers, apps, repos synced across all Tailscale-connected servers. Gives any agent on any server instant awareness of the entire ecosystem.
