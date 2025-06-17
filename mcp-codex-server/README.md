# MCP Codex Server

An MCP (Model Context Protocol) server that provides a proper interface for the Codex code review tool, ensuring consistent and correct usage.

## Problem Solved

This MCP server addresses the common issue where Codex is called incorrectly, leading to failures that are often ignored instead of being corrected. By providing a structured interface with proper error handling and environment setup, it ensures Codex is used correctly for peer review and consultation.

## Features

- **Structured Tools**: Provides specific tools for different Codex use cases
- **Automatic Environment Setup**: Handles `.env` file loading and API key configuration
- **Docker Compatibility**: Always uses quiet mode (`-q`) for proper Docker operation
- **Context Management**: Optionally includes project documentation (CLAUDE.md) for better reviews
- **Error Handling**: Provides clear error messages when configuration is missing

## Available Tools

### 1. `codex_review`
Request a code review or evaluation from Codex.
```json
{
  "prompt": "review the recent changes to the Docker setup",
  "include_project_context": true
}
```

### 2. `codex_consult`
Consult with Codex about implementation decisions or best practices.
```json
{
  "question": "what's the best way to handle container lifecycle management?"
}
```

### 3. `codex_status`
Get a summary of the current project state.
```json
{}
```

### 4. `codex_history`
View past Codex consultation sessions.
```json
{
  "limit": 5
}
```

## Installation

1. Install dependencies:
```bash
cd /claudex/mcp-codex-server
npm install
```

2. Ensure your OPENAI_API_KEY is set in your environment or `.env` file:
```bash
echo "OPENAI_API_KEY=your-key-here" >> .env
```

3. Add to your MCP configuration (e.g., in Claude Desktop settings):
```json
{
  "mcpServers": {
    "codex": {
      "command": "node",
      "args": ["/path/to/mcp-codex-server/index.js"]
    }
  }
}
```

## Usage Examples

When using with Claude or another MCP-compatible assistant:

1. **Review Recent Changes**:
   "Use the codex_review tool to review our recent Docker configuration changes"

2. **Get Implementation Guidance**:
   "Use codex_consult to ask about best practices for error handling in our MCP server"

3. **Check Project Status**:
   "Use codex_status to get an overview of the current project state"

## Integration with Claudex

This MCP server is designed to work seamlessly within Claudex containers. When installed globally or included in the container image, it ensures that all AI assistants properly consult with Codex for peer review as specified in the project guidelines.

## Troubleshooting

### "OPENAI_API_KEY not found" Error
- Ensure your API key is set in the environment or `.env` file
- The server will automatically try to load from `.env` if not found in environment

### "Failed to execute codex" Error
- Ensure the `@openai/codex` package is installed globally or in your PATH
- Check that you're running within a Claudex container where codex is pre-installed

### No Output or Hanging
- The server always uses quiet mode (`-q`) to prevent terminal rendering issues in Docker
- If codex still hangs, check that your Docker container has proper TTY allocation