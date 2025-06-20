#!/bin/bash

# Docker entrypoint script for Claudex containers
# This ensures Qdrant auto-start works regardless of how the container is entered

# Function to ensure MCP configuration exists
ensure_mcp_config() {
  # Check if .mcp.json already exists in home directory
  if [ ! -f "$HOME/.mcp.json" ]; then
    # Create the MCP configuration for Codex server
    cat > "$HOME/.mcp.json" << 'EOF'
{
  "mcpServers": {
    "codex": {
      "command": "mcp-codex-wrapper",
      "args": [],
      "env": {
        "NODE_ENV": "production"
      }
    }
  }
}
EOF
    echo "✓ MCP configuration initialized at ~/.mcp.json"
  fi
}

# Function to start Qdrant if enabled
start_qdrant_if_enabled() {
  # Check if auto-start is enabled (default: true)
  if [ "${CLAUDEX_AUTO_START_QDRANT:-true}" = "true" ]; then
    # Create .qdrant directory if it doesn't exist
    mkdir -p ~/.qdrant
    
    # Log startup attempt
    echo "[$(date)] Attempting Qdrant auto-start via entrypoint" >> ~/.qdrant/startup.log
    
    # Check if Qdrant is already running
    if qdrant-manager status >/dev/null 2>&1 && pgrep -f "qdrant" >/dev/null 2>&1; then
      echo "[$(date)] Qdrant already running, skipping auto-start" >> ~/.qdrant/startup.log
    else
      # Start Qdrant with optional quiet mode
      if [ "${CLAUDEX_QDRANT_STARTUP_QUIET:-true}" = "false" ]; then
        echo "Starting Qdrant vector database..."
        if qdrant-manager start; then
          echo "[$(date)] Qdrant started successfully via entrypoint" >> ~/.qdrant/startup.log
        else
          echo "[$(date)] Qdrant startup failed via entrypoint" >> ~/.qdrant/startup.log
        fi
      else
        if qdrant-manager start >/dev/null 2>&1; then
          echo "[$(date)] Qdrant started successfully via entrypoint (quiet mode)" >> ~/.qdrant/startup.log
          # Show a brief message on first startup
          if [ ! -f ~/.qdrant/.first-start-shown ]; then
            echo "✓ Qdrant vector database started (port ${QDRANT_PORT:-6333})"
            touch ~/.qdrant/.first-start-shown
          fi
        else
          echo "[$(date)] Qdrant startup failed via entrypoint (quiet mode)" >> ~/.qdrant/startup.log
        fi
      fi
    fi
  else
    echo "[$(date)] Qdrant auto-start disabled via CLAUDEX_AUTO_START_QDRANT=false" >> ~/.qdrant/startup.log
  fi
}

# Initialize environment on container startup
ensure_mcp_config

# Start Qdrant if this is the main process
if [ "$1" = "bash" ] || [ -z "$1" ]; then
  start_qdrant_if_enabled
fi

# Execute the original command
exec "$@"