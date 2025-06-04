# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claudex is a Docker-based development environment manager that creates isolated, project-specific containers with AI coding assistants pre-installed. Each project gets its own named container with persistent environment data.

## Key Commands

### Building and Managing the Docker Image
```bash
# Build the Docker image
make build

# Force rebuild from scratch
make rebuild

# Remove the Docker image
make clean
```

### Managing Project Environments
```bash
# Start a new project environment (creates container if doesn't exist)
./claudex.sh projname /path/to/source/code

# Reattach to existing project container
./claudex.sh projname

# Stop and remove a project container
./claudex.sh stop projname

# List all running containers and environments
./claudex.sh list

# Clean up stopped containers (single project or all with -a)
./claudex.sh cleanup projname
./claudex.sh cleanup -a
```

## Architecture

The system uses a container-per-project approach where:
- Each project runs in its own Docker container named `claudex_[projname]`
- Project source code is mounted from host to container at `/[projname]`
- Environment data persists in `~/.claude_[projname]` on the host, mounted to `/home/claudex/.claude` in container
- Containers can be stopped and restarted while preserving environment state

## Important Implementation Details

- The main entry point is `claudex.sh` which handles all container lifecycle management
- The Dockerfile creates a Node.js environment with `@anthropic-ai/claude-code` and `@openai/codex` pre-installed
- Containers run as non-root user `claudex` for security
- The script includes safety checks and confirmation prompts for destructive operations
- Environment timestamps are tracked in `~/.claude_[projname]/.last_used` for the list command