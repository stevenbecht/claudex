# MCP Codex Output Truncation Fix

## Problem
The MCP Codex server was always using the `-q` (quiet) flag when calling the codex CLI, which resulted in truncated output showing only the assistant's final response without the full conversation context.

## Root Cause
In `/claudex/mcp-codex-server/index.js`, line 146 had:
```javascript
const cmdArgs = ['-q', ...args]; // Always use quiet mode for Docker compatibility
```

This forced quiet mode for all MCP tool calls, limiting the output to just the final response.

## Solution
1. Made quiet mode optional by adding a `quiet` parameter to all MCP tools
2. Modified the `executeCodex` method to accept options and only add `-q` when explicitly requested
3. Default behavior is now `quiet: false` for full conversation output

## Changes Made

### 1. Added optional `quiet` parameter to all tools:
- `codex_review`: Added `quiet: boolean` parameter (default: false)
- `codex_consult`: Added `quiet: boolean` parameter (default: false)  
- `codex_status`: Added `quiet: boolean` parameter (default: false)
- `codex_history`: No change needed (uses different flag)

### 2. Modified executeCodex method:
```javascript
async executeCodex(args, options = {}) {
  // ...
  const cmdArgs = [];
  
  // Only add quiet flag if explicitly requested
  if (options.quiet) {
    cmdArgs.push('-q');
  }
  
  cmdArgs.push(...args);
  // ...
}
```

### 3. Updated all handler methods to pass quiet option:
```javascript
const output = await this.executeCodex(codexArgs, { quiet });
```

## Benefits
- Users now get full conversation context by default
- Can still opt-in to quiet mode when needed (e.g., for automated scripts)
- Backwards compatible - existing code continues to work
- More flexible for different use cases

## Testing
Created `/claudex/test-mcp-quiet-mode.js` to verify the quiet parameter works correctly with different values.