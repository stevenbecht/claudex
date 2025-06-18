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

### Using CodeQuery (cq) for AI-Powered Code Search
Each container includes CodeQuery (cq), a tool that uses Qdrant and OpenAI to embed and search your codebase:

```bash
# Set your OpenAI API key (required)
# Option 1: Set it temporarily for this session
export OPENAI_API_KEY='your-api-key-here'

# Option 2: Save it in a .env file for automatic loading
echo "OPENAI_API_KEY=your-api-key-here" >> .env

# The cq command will automatically load the .env file from:
# 1. Current directory (.env)
# 2. Home directory (~/.env) if not found in current directory

# Start Qdrant first (CodeQuery uses it for vector storage)
qstart  # or: claudex qdrant myapp start

# Embed your codebase into Qdrant
cq embed /path/to/code --project myproject

# Search your codebase with natural language
cq search "function that handles authentication" --project myproject

# Interactive chat with code context
cq chat --project myproject

# View embedding statistics
cq stats --project myproject

# Apply code changes from chat (XML diff format)
cq diff changes.xml --project myproject
```

CodeQuery features:
- Natural language code search using embeddings
- Interactive chat with codebase context
- Language-aware code parsing
- Incremental embedding updates
- XML-based diff application
- Works seamlessly with the integrated Qdrant instance

## Architecture

The system uses a container-per-project approach where:
- Each project runs in its own Docker container named `claudex_[project]`
- Project source code is mounted from host to container at `/[project]`
- Environment data persists in `~/claudex/[project]` on the host, mounted to `/home/claudex` in container
- Containers can be stopped and restarted while preserving environment state

## Important Implementation Details

- The main entry point is `claudex.sh` which handles all container lifecycle management
- The Dockerfile creates a Node.js environment with `@anthropic-ai/claude-code` and `@openai/codex` pre-installed
- CodeQuery is installed in a Python venv at `/opt/codequery` with the `cq` command available globally
- Both `cq` and `mcp-codex-wrapper` automatically load `.env` files for consistent environment variable handling
- Environment variables (like `OPENAI_API_KEY`) are loaded from `.env` in current directory first, then `~/.env` as fallback
- Containers run as non-root user `claudex` for security
- The script includes safety checks and confirmation prompts for destructive operations
- All commands provide clear feedback with color-coded status messages
- Container names follow the pattern `claudex_[project]` for easy identification

## MCP Codex Server Integration

To ensure proper and consistent use of Codex for peer review, an MCP (Model Context Protocol) server is available that provides structured tools for Codex interaction:

### Available MCP Tools:
- **codex_review**: Request code reviews with automatic project context inclusion
- **codex_consult**: Get implementation guidance and best practices
- **codex_status**: Get project status summary
- **codex_history**: View past consultation sessions

### Benefits:
- Automatic environment setup (API keys, .env loading)
- Docker-compatible quiet mode by default
- Structured error handling and clear feedback
- Prevents common mistakes like missing quotes or environment variables

### Setup:
To enable the MCP Codex server in Claude Code, run:
```bash
claude mcp add codex mcp-codex-wrapper
```

This only needs to be done once per container. The server will then be available for all Claude Code sessions.

### Usage:
When MCP is configured, use the tools directly instead of raw commands:
- Instead of: `codex "review changes"`
- Use: `codex_review` tool with prompt "review the recent changes"

## Memories

- We use the program Codex for evaluation of changes to ensure they are peer reviewed
- IMPORTANT: When asked to consult with Codex, use the command: `codex "your question here"`
- PREFERRED: When MCP is available, use the codex_review, codex_consult tools instead of direct commands
- We are running inside a container, so we cannot test Docker commands directly
- Always consult Codex when implementing significant features or when explicitly asked