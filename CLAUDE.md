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
# Start a new project environment (first time)
claudex start myapp --dir ~/projects/myapp

# Start with port mappings (e.g., host:container)
claudex start myapp --dir ~/projects/myapp --port 8080,3000:3000

# Reattach to existing project container
claudex start myapp

# Stop a running container (keeps it for later)
claudex stop myapp

# Remove a container (stopped or running)
claudex remove myapp

# Restart an existing container
claudex restart myapp

# Upgrade container to latest image after rebuild
claudex upgrade myapp        # Single project (container must be stopped)
claudex upgrade --all        # All containers
claudex upgrade myapp --force # Force upgrade even if running

# Upgrade workflow:
# 1. Rebuild the image: make rebuild
# 2. Upgrade containers: claudex upgrade myapp
# Note: The upgrade process creates a backup, replaces the container,
#       and restores the original if upgrade fails

# Show all environments or specific project status
claudex status
claudex status myapp

# View container logs (with optional live follow)
claudex logs myapp
claudex logs myapp --follow

# Clean up stopped containers
claudex cleanup myapp        # Single project
claudex cleanup --all        # All stopped containers

# Get help
claudex help
```

### Managing Qdrant Vector Database
Each project container can run its own Qdrant instance for vector search capabilities:

```bash
# Start Qdrant in a project (downloads binary on first use)
claudex qdrant myapp start

# Stop Qdrant
claudex qdrant myapp stop

# Check Qdrant status
claudex qdrant myapp status

# View Qdrant logs
claudex qdrant myapp logs
claudex qdrant myapp logs -f  # Follow logs

# Restart Qdrant
claudex qdrant myapp restart

# Clean Qdrant data (requires confirmation)
claudex qdrant myapp clean
```

Inside the container, you can also use these shortcuts:
```bash
qstart   # Start Qdrant
qstop    # Stop Qdrant
qs       # Check status
qlogs    # Follow logs
qdrant   # Full qdrant-manager command
```

Qdrant features:
- Runs on port 6333 by default (configurable with QDRANT_PORT env var)
- API endpoint: http://localhost:6333
- Dashboard: http://localhost:6333/dashboard
- Data persists in ~/claudex/[project]/.qdrant/
- Automatically detects architecture (aarch64 for Mac, x86_64 for Linux)
- No additional containers or complex networking required

## Architecture

The system uses a container-per-project approach where:
- Each project runs in its own Docker container named `claudex_[project]`
- Project source code is mounted from host to container at `/[project]`
- Environment data persists in `~/claudex/[project]` on the host, mounted to `/home/claudex` in container
- Containers can be stopped and restarted while preserving environment state

## Important Implementation Details

- The main entry point is `claudex.sh` which handles all container lifecycle management
- The Dockerfile creates a Node.js environment with `@anthropic-ai/claude-code` and `@openai/codex` pre-installed
- Containers run as non-root user `claudex` for security
- The script includes safety checks and confirmation prompts for destructive operations
- All commands provide clear feedback with color-coded status messages
- Container names follow the pattern `claudex_[project]` for easy identification

## Memories

- We use the program Codex for evaluation of changes to ensure they are peer reviewed
- IMPORTANT: When asked to consult with Codex, use the command: `codex "your question here"`
- We are running inside a container, so we cannot test Docker commands directly
- Always consult Codex when implementing significant features or when explicitly asked