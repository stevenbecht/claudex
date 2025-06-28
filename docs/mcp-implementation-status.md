# MCP Implementation Status Report
*Last Updated: 2025-06-28*

## Current Status: Phase 1 Complete (Pending Testing)

This document captures the current state of the MCP (Model Context Protocol) implementation for Claudex. **CRITICAL: The Docker image must be rebuilt before testing can proceed.**

## Completed Work

### Phase 0: Security & Core Infrastructure ✅

#### 0.1 Environment Configuration ✅
- **Created** `scripts/mcp-utils.sh` - Complete utility library for MCP operations
- **Modified** `claudex.sh` - Added `CLAUDEX_MCP_REGISTRY` env var support in:
  - `cmd_start()` function (line 228)
  - `cmd_upgrade()` function (line 632)
- **Modified** `Dockerfile`:
  - Added MCP directory structure at line 38-43
  - Set `CLAUDEX_MCP_REGISTRY` environment variable
  - Moved Codex server to new location: `/opt/mcp-servers/core/codex/`
  - Added copy of `mcp-utils.sh` to `/opt/`

#### 0.2 JSON Schema Definitions ⚠️ SKIPPED
- Per Codex feedback, we skipped formal JSON schemas to avoid over-engineering
- Using basic validation in `mcp-utils.sh` instead

#### 0.3 Caching System ✅
- Implemented in `mcp-utils.sh`:
  - `update_mcp_cache()` function
  - `is_cache_valid()` function  
  - `get_cached_registry()` function
  - Cache location: `~/.cache/claudex/mcp/registry.json`
  - 5-minute TTL

#### 0.4 Atomic Operations ⚠️ PARTIAL
- Basic locking implemented in `mcp-utils.sh`:
  - `acquire_mcp_lock()` function
  - `release_mcp_lock()` function
- Full atomic install/remove scripts not created (deferred)

### Phase 1: MCP Registry & Configuration System ✅

#### 1.1 Registry Structure ✅
- Defined in Dockerfile but NOT YET BUILT
- Structure: `/opt/mcp-servers/{core,installed,disabled}/`
- Registry index: `/opt/mcp-servers/registry.json`

#### 1.2 Configuration Layering ✅
- Implemented in `generate_mcp_config()` function in `mcp-utils.sh`
- Deep merge using jq (lines 228-233)
- Precedence: Registry → Project overrides

#### 1.3 Manifest Structure ✅
- **Created** `mcp-codex-server/manifest.json`:
```json
{
  "apiVersion": "v1",
  "metadata": {
    "name": "codex",
    "version": "1.0.0",
    "description": "Code review and consultation via Codex",
    "author": "Claudex Team",
    "license": "MIT"
  },
  "server": {
    "command": "mcp-codex-wrapper",
    "args": [],
    "env": {
      "NODE_ENV": "production"
    },
    "capabilities": ["tools"],
    "requiredEnv": ["OPENAI_API_KEY"]
  }
}
```

#### 1.4 Docker Entrypoint Updates ✅
- **Modified** `scripts/docker-entrypoint.sh`:
  - Sources `/opt/mcp-utils.sh` if available
  - Uses `generate_mcp_config` if MCP utilities exist
  - Falls back to hardcoded config if not

#### Additional Files Created
- **Created** `scripts/test-mcp-registry.sh` - Test script for validation
- **Modified** `scripts/mcp-codex-wrapper.sh` - Updated path to use `$CLAUDEX_MCP_REGISTRY`

## Critical Next Steps

### 1. EXIT THE CONTAINER
The current container has the OLD structure. All our changes are in files but the Docker image needs rebuilding.

### 2. REBUILD THE DOCKER IMAGE
From the host machine (NOT inside container):
```bash
make rebuild
```

### 3. START A NEW TEST CONTAINER
```bash
claudex start mcp-test --dir /tmp/mcp-test
```

### 4. TEST INSIDE THE NEW CONTAINER
```bash
# Inside the new container:
source /opt/mcp-utils.sh
/claudex/scripts/test-mcp-registry.sh
```

### 5. VERIFY MCP CONFIGURATION
```bash
# Check that MCP config was generated correctly
cat ~/.mcp.json

# Verify Codex server is in new location
ls -la /opt/mcp-servers/core/codex/
```

## Known Issues & Gotchas

1. **Container Context**: We made changes inside a container that won't persist. All changes are in the `/claudex` mount, but the `/opt/` structure needs the image rebuild.

2. **Path Changes**: The Codex server will move from `/opt/mcp-codex-server/` to `/opt/mcp-servers/core/codex/` after rebuild.

3. **Testing Confusion**: We created temporary test structures in `/tmp/` which should be ignored. Only test with the real `/opt/mcp-servers/` after rebuild.

4. **Simplified Approach**: We skipped JSON schemas and complex validation per Codex feedback to avoid over-engineering.

## Files Modified/Created Summary

### New Files:
- `/claudex/scripts/mcp-utils.sh`
- `/claudex/scripts/test-mcp-registry.sh`
- `/claudex/mcp-codex-server/manifest.json`
- `/claudex/docs/mcp-implementation-status.md` (this file)

### Modified Files:
- `/claudex/claudex.sh` (env var support)
- `/claudex/Dockerfile` (MCP structure)
- `/claudex/scripts/docker-entrypoint.sh` (MCP config generation)
- `/claudex/scripts/mcp-codex-wrapper.sh` (path update)

## Phase 2 Preview

Once testing confirms Phase 1 works, Phase 2 will add CLI commands:
- `claudex mcp list`
- `claudex mcp enable/disable`
- `claudex mcp status`
- etc.

## Recovery Instructions

If something goes wrong after leaving this session:

1. Check this status document first
2. Review the implementation plan: `/claudex/docs/mcp-implementation-plan.md`
3. Key files to examine:
   - `/claudex/scripts/mcp-utils.sh` - Core MCP logic
   - `/claudex/Dockerfile` - See MCP structure setup
   - Test with: `/claudex/scripts/test-mcp-registry.sh`
4. The goal: Make it easy to add new MCP servers beyond just Codex

## Important Notes

- **DO NOT** try to test MCP features without rebuilding the Docker image first
- **DO NOT** rely on any `/tmp/test-*` directories - these were temporary
- **REMEMBER** The current container has the old structure at `/opt/mcp-codex-server/`
- **AFTER REBUILD** The new structure will be at `/opt/mcp-servers/core/codex/`

## Environment Variables

### New Environment Variable: CLAUDEX_MCP_REGISTRY
- **Default**: `/opt/mcp-servers`
- **Purpose**: Allows customizing the MCP registry location
- **Usage**: `CLAUDEX_MCP_REGISTRY=/custom/path claudex start myproject`
- **Note**: This env var is passed through to containers via `claudex.sh`

## Permissions Added

The following permissions were added to `.claude/settings.local.json` during development:
- `Bash(shellcheck:*)` - For validating shell scripts
- `Bash(CLAUDEX_MCP_REGISTRY=...)` - For testing with custom registry paths

## What Was Deferred/Skipped

1. **JSON Schema Validation** - Skipped per Codex recommendation to avoid over-engineering
2. **Full Atomic Operations** - Only basic locking implemented, full atomic install/remove deferred
3. **mcp-config.sh** - Not created, configuration merging integrated into mcp-utils.sh
4. **validate-schema.sh** - Not created, using simple validation in mcp-utils.sh

## Testing Checklist

After rebuilding the image, verify:
- [ ] `/opt/mcp-servers/` directory exists with proper structure
- [ ] Codex server is at `/opt/mcp-servers/core/codex/`
- [ ] `~/.mcp.json` is generated automatically on container start
- [ ] `source /opt/mcp-utils.sh` works without errors
- [ ] `test-mcp-registry.sh` passes all tests
- [ ] MCP tools still work in Claude Code

## Future Documentation Updates Needed

Once testing is complete:
1. Update `CLAUDE.md` to document the `CLAUDEX_MCP_REGISTRY` environment variable
2. Update `README.md` to mention MCP architecture if adding user-facing features
3. Update implementation plan to mark Phase 0 and 1 as complete

## Key Functions in mcp-utils.sh

For future reference, here are the main functions available:

### Registry Management
- `get_mcp_registry()` - Get the registry path (respects CLAUDEX_MCP_REGISTRY env var)
- `check_mcp_registry()` - Verify registry exists and is readable
- `create_mcp_directories()` - Create registry structure with proper permissions

### Server Management
- `list_mcp_servers()` - List all available MCP servers
- `validate_mcp_server()` - Validate a server's structure and manifest
- `get_mcp_server_metadata()` - Get server manifest data
- `is_mcp_server_enabled()` - Check if server is enabled
- `print_mcp_server_info()` - Display server information

### Configuration
- `generate_mcp_config()` - Generate ~/.mcp.json from registry (supports project overrides)
- `get_mcp_project_config_dir()` - Get project-specific MCP config directory

### Caching
- `update_mcp_cache()` - Update registry cache
- `is_cache_valid()` - Check if cache is fresh (5 min TTL)
- `get_cached_registry()` - Get cached registry data

### Utilities
- `acquire_mcp_lock()` / `release_mcp_lock()` - Simple locking mechanism