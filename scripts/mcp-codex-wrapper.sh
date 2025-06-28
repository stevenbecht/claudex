#!/bin/bash

# MCP Codex Server wrapper for Claudex containers
# This script ensures the MCP server runs with proper environment setup

# Source .env if it exists in the current directory
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs -0)
fi

# Check for OPENAI_API_KEY
if [ -z "$OPENAI_API_KEY" ]; then
    # Try to find it in the home directory .env
    if [ -f "$HOME/.env" ]; then
        export $(grep -v '^#' "$HOME/.env" | grep "OPENAI_API_KEY" | xargs -0)
    fi
fi

# Run the MCP server from new location
exec node ${CLAUDEX_MCP_REGISTRY:-/opt/mcp-servers}/core/codex/index.js "$@"