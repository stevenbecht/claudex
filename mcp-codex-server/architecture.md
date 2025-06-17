# MCP Codex Server Architecture

## Overview

The MCP Codex Server provides a structured interface between AI assistants and the Codex peer review tool, ensuring consistent and correct usage.

```
┌─────────────────────┐
│   AI Assistant      │
│ (Claude, etc.)      │
└──────────┬──────────┘
           │ MCP Protocol
           ▼
┌─────────────────────┐
│  MCP Codex Server   │
│                     │
│ Tools:              │
│ - codex_review      │
│ - codex_consult     │
│ - codex_status      │
│ - codex_history     │
└──────────┬──────────┘
           │ Subprocess
           ▼
┌─────────────────────┐
│   Codex CLI Tool    │
│ (@openai/codex)     │
└──────────┬──────────┘
           │ API
           ▼
┌─────────────────────┐
│   OpenAI API        │
│ (Code Review LLM)   │
└─────────────────────┘
```

## Components

### 1. MCP Server (index.js)
- Implements MCP protocol for tool discovery and execution
- Handles environment setup (API keys, .env loading)
- Provides structured error handling
- Always uses quiet mode (-q) for Docker compatibility

### 2. Wrapper Script (mcp-codex-wrapper.sh)
- Ensures proper environment variables are loaded
- Searches for API keys in multiple locations
- Launches the MCP server with correct configuration

### 3. Integration Points

#### Docker Integration
```dockerfile
# Installed at /opt/mcp-codex-server
# Available via mcp-codex-wrapper command
```

#### MCP Client Configuration
```json
{
  "mcpServers": {
    "codex": {
      "command": "mcp-codex-wrapper"
    }
  }
}
```

## Benefits

1. **Consistency**: Structured tools ensure correct syntax and parameters
2. **Error Prevention**: Automatic environment setup prevents common failures
3. **Docker Support**: Built-in quiet mode prevents TTY issues
4. **Context Awareness**: Optionally includes project documentation for better reviews
5. **History Tracking**: Access to past consultation sessions

## Usage Flow

1. User requests code review via AI assistant
2. AI assistant calls `codex_review` tool via MCP
3. MCP server validates parameters and environment
4. Server executes codex CLI with proper arguments
5. Results are returned in structured format
6. AI assistant presents results to user