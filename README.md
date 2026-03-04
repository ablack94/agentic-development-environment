# Agentic Development Environment

A sandboxed environment where AI agents collaborate on software projects using Git-native workflows. Agents take on roles (project manager, developer), interact through a shared Gitea instance for source control and issue tracking, and have all activity recorded via an audit service.

## Why

Claude agents are surprisingly capable on long-running, goal-oriented tasks when prompted directly. This project explores whether adding structure — roles, issue tracking, code review, audit trails — can sustain that capability over even longer and more complex tasks. It's a step toward using Claude autonomously in ways that are feasible and productive.

## Architecture

```
                  +-----------+
  POST /command   |   Agent   |   Claude Code CLI
  ------------->  |  (Flask)  |   + Gitea MCP
                  +-----+-----+
                        |
            +-----------+-----------+
            |                       |
      +-----v-----+         +------v------+
      |   Gitea    |         |   Audit     |
      |  (git +    |         |  Service    |
      |  issues)   |         |  (SQLite)   |
      +------------+         +-------------+
```

**Gitea** provides repositories, issues, and pull requests. Agents interact with it via [gitea-mcp](https://github.com/gitea/gitea-mcp).

**Agents** run Claude Code as a subprocess, configured with role-based prompts. A hook system intercepts all tool usage and publishes events to the audit service.

**Audit Service** records every agent action with timestamps for full traceability.

**Networking** -- Two Docker networks provide isolation. Agents, Gitea, and the audit service all live on an `internal` sandbox network with no outbound internet. The nginx gateway is the only service that bridges both the sandbox and `ingress` networks. It serves as the sole entry point from the host (via virtual hosts: `gitea.localhost`, `audit.localhost`, `mark.localhost`) and also acts as a whitelisted egress proxy — agents route Claude API calls through the gateway on port 8443, which forwards to `api.anthropic.com`. This keeps agents network-isolated while allowing only the specific upstream they need.

## Roles

Agents are configured with composable role prompts (see `prompts/`):

- **BASE** -- Core instructions for autonomy, memory, and structured responses
- **PROJECT_MANAGER** -- Strategic planning, high-level reasoning, assumption questioning
- **DEVELOPER** -- Issue triage, implementation, PRs, and code review

## Getting Started

### Prerequisites

- Docker (or Podman) and Docker Compose
- A Claude OAuth token (set via `CLAUDE_OAUTH_TOKEN` in `compose.yaml`)
- TCP port 3001 (for gateway access from host)
- curl (for scripts/run-scenario.sh)

### Run

```bash
# Start all services (Gitea auto-configures on first boot)
docker compose up -d

# Run a scenario
./scripts/run-scenario.sh scenarios/build_tail_1.json

# Visit gitea in a web browser (login with admin/admin)
http://gitea.localhost:3001/
# Specifically you'll want to see mark's user account
http://gitea.localhost:3001/mark

# Inspect audits
./scripts/dump-audits.sh

# Teardown / Cleanup
docker compose down --volumes
```

## Project Structure

```
agent/
  Dockerfile          # Ubuntu-based agent image with Claude Code CLI
  agent.py            # Flask server -- accepts prompts, runs Claude Code
  audit.py            # Hook script -- intercepts tool calls, publishes to audit
  entrypoint.sh       # Configures MCP, git credentials, role prompts, starts server
  settings.json       # Claude Code configuration
audit/
  Dockerfile          # Python 3.13 audit service image
  main.py             # Flask API -- stores and retrieves audit records
gateway/
  nginx.conf          # Reverse proxy -- routes host traffic into the sandbox network
gitea/
  setup-gitea.sh      # Creates admin + agent users, generates access tokens
prompts/
  BASE.md             # Core agent behavior
  PROJECT_MANAGER.md  # PM role prompt
  DEVELOPER.md        # Developer role prompt
scenarios/
  build_tail_1.json   # Example scenario -- build a tail clone in Rust
scripts/
  run-scenario.sh     # Send a scenario JSON to an agent
  dump-audits.sh      # Dump audit records from the audit service
compose.yaml          # Orchestrates all services
```

## Known Limitations

- **Audit integrity** -- The audit service accepts writes over plain HTTP on a shared Docker network. A misbehaving agent could post fabricated audit records directly to the TCP port, bypassing the hook system. Future work: authenticate audit submissions (e.g., signed payloads or a sidecar proxy) and make the audit log append-only at the storage layer.

## Roadmap

- **Event sourcing** -- Required for distributing agents across separate containers
- **1-pod-1-agent** -- Move from sub-agent multi-agent behavior to isolated agent containers
- **Claude Agent SDK** -- Investigate replacing the Claude Code CLI subprocess with the Agent SDK for more direct control over agent behavior
- **Rust services** -- Rewrite the agent and audit web services in Rust
