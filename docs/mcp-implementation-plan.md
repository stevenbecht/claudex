# Claudex MCP Architecture Implementation Plan

## Overview
This plan details the step-by-step implementation of the extensible MCP (Model Context Protocol) architecture for Claudex, incorporating feedback from Codex review.

## Phase 0: Security & Core Infrastructure (Week 1)

### 0.1 Environment Configuration
- Add `CLAUDEX_MCP_REGISTRY` environment variable (default: `/opt/mcp-servers`)
- Create `scripts/mcp-utils.sh` with helper functions
- Update Dockerfile to create MCP directories with proper permissions (755 for dirs, 644 for files)
- Add MCP user/group management for secure execution

### 0.2 JSON Schema Definitions
- Create `schemas/manifest-v1.schema.json` for server manifests
- Create `schemas/registry-v1.schema.json` for registry structure
- Create `schemas/config-v1.schema.json` for MCP configurations
- Add schema validation utility in `scripts/validate-schema.sh`

### 0.3 Caching System
- Implement registry cache at `~/.cache/claudex/mcp-registry.json`
- Add cache invalidation hooks
- Create cache management utilities
- Include cache TTL and forced refresh options

### 0.4 Atomic Operations
- Create `scripts/mcp-atomic.sh` for safe install/remove
- Implement staging directory approach (`/tmp/mcp-staging/`)
- Add rollback capability for failed operations
- Use file locking to prevent concurrent modifications

### Deliverables:
- [ ] Environment variable support in Docker and scripts
- [ ] Complete schema definitions with validation
- [ ] Working cache system with < 10ms lookup time
- [ ] Atomic operation scripts with rollback support

## Phase 1: MCP Registry & Configuration System (Week 2)

### 1.1 Registry Structure
```
${CLAUDEX_MCP_REGISTRY}/
├── registry.json          # Master registry index
├── core/                  # Built-in servers (ship with Claudex)
│   └── codex/
│       ├── manifest.json
│       ├── index.js
│       └── package.json
├── installed/             # User-installed servers
│   ├── qdrant/
│   └── codequery/
└── disabled/              # Disabled servers (preserved)
    └── .gitkeep
```

### 1.2 Configuration Layering
- Implement merge strategy in `scripts/mcp-config.sh`
- Create configuration precedence: Global → Registry → Project → User
- Add deep-merge for objects, overwrite for scalars
- Support environment variable expansion in configs

### 1.3 Manifest Structure
```json
{
  "apiVersion": "v1",
  "metadata": {
    "name": "server-name",
    "version": "1.0.0",
    "description": "Brief description",
    "author": "Author Name",
    "license": "MIT",
    "homepage": "https://..."
  },
  "server": {
    "command": "node",
    "args": ["index.js"],
    "env": {
      "NODE_ENV": "production"
    },
    "capabilities": ["tools", "prompts", "resources"],
    "requiredEnv": ["OPENAI_API_KEY"],
    "optionalEnv": ["DEBUG_LEVEL"]
  },
  "compatibility": {
    "claudex": ">=1.0.0",
    "mcp": ">=1.0.0"
  },
  "healthCheck": {
    "endpoint": "/health",
    "interval": 30,
    "timeout": 5
  }
}
```

### 1.4 Docker Entrypoint Updates
- Modify `scripts/docker-entrypoint.sh` to use new MCP system
- Add registry scanning on startup (with caching)
- Generate dynamic `~/.mcp.json` from registry
- Support hot-reload via file watching (optional)

### Deliverables:
- [ ] Complete registry directory structure
- [ ] Working configuration merge system
- [ ] Manifest validation and loading
- [ ] Updated Docker entrypoint with < 100ms overhead

## Phase 2: CLI Commands & Management (Week 3)

### 2.1 Core MCP Commands
```bash
# Discovery and status
claudex mcp list                    # Show all available servers
claudex mcp list --enabled          # Show only enabled servers
claudex mcp status                  # Show active servers and health
claudex mcp status <server>         # Detailed status for one server

# Enable/disable servers
claudex mcp enable <server>         # Enable globally
claudex mcp enable <server> --project myapp  # Enable for project
claudex mcp disable <server>        # Disable (preserves config)

# Configuration management
claudex mcp config show <server>    # Show current config
claudex mcp config explain <server> # Show merged config with sources
claudex mcp config set <server> <key> <value>  # Update config
```

### 2.2 Developer Commands
```bash
# Server development
claudex mcp create <name>           # Interactive scaffolding
claudex mcp validate <path>         # Validate server structure
claudex mcp test <server>           # Run server tests
claudex mcp logs <server>           # View server logs

# Installation
claudex mcp install <git-url>       # Install from git
claudex mcp install <path>          # Install from local path
claudex mcp uninstall <server>      # Remove server
claudex mcp upgrade <server>        # Upgrade to latest version
```

### 2.3 Server Lifecycle Management
- Install validates manifest before copying
- Version conflict detection and resolution
- Dependency checking (npm, python, etc.)
- Health check integration
- Graceful shutdown on disable

### Deliverables:
- [ ] All CLI commands implemented in `claudex.sh`
- [ ] Command help and documentation
- [ ] Error handling and user feedback
- [ ] Integration tests for all commands

## Phase 3: MCP Server Implementation (Weeks 4-5)

### 3.1 Migrate Existing Codex Server
- Move to `core/codex/` with new structure
- Update manifest to v1 format
- Add health check endpoint
- Ensure backward compatibility

### 3.2 Qdrant MCP Server (`mcp-servers/qdrant/`)
```javascript
// Available tools:
- qdrant_start: Start Qdrant instance
- qdrant_stop: Stop Qdrant instance  
- qdrant_status: Check Qdrant status
- qdrant_create_collection: Create vector collection
- qdrant_search: Vector similarity search
- qdrant_upsert: Insert/update vectors
- qdrant_delete: Delete vectors
```

### 3.3 CodeQuery MCP Server (`mcp-servers/codequery/`)
```javascript
// Available tools:
- cq_embed: Embed codebase into vectors
- cq_search: Natural language code search
- cq_chat: Interactive chat with context
- cq_stats: Embedding statistics
- cq_apply_diff: Apply code changes
```

### 3.4 OpenAI/Claude Wrapper (`mcp-servers/llm-wrapper/`)
- Generic template for LLM providers
- Environment-based configuration
- Rate limiting and retry logic
- Token counting and limits
- Streaming support

### 3.5 Docker Management Server (`mcp-servers/docker-mgmt/`)
```javascript
// Available tools:
- docker_ps: List containers
- docker_start: Start container
- docker_stop: Stop container
- docker_logs: View container logs
- docker_exec: Execute command in container
- docker_stats: Resource usage
```

### Deliverables:
- [ ] All servers implemented with standard structure
- [ ] Comprehensive tool documentation
- [ ] Unit tests for each server
- [ ] Example usage in README.md

## Phase 4: Developer Experience (Week 6)

### 4.1 Scaffolding Tool
```bash
$ claudex mcp create my-server
? Server type: (Use arrow keys)
❯ Standard MCP Server (Node.js)
  Python MCP Server
  Shell Script Wrapper
  Custom Template

? Description: My awesome MCP server
? Author: John Doe
? License: MIT
? Initial tools: tool1, tool2

✓ Created server structure at ./my-server/
✓ Initialized package.json
✓ Created manifest.json
✓ Added example tools
✓ Generated README.md

Next steps:
  cd my-server
  npm install
  claudex mcp validate .
  claudex mcp test .
```

### 4.2 Documentation Structure
```
docs/
├── mcp-development.md      # Developer guide
├── mcp-architecture.md     # Architecture overview
├── mcp-api-reference.md    # API documentation
├── mcp-examples/           # Example servers
│   ├── hello-world/
│   ├── database-query/
│   └── api-wrapper/
└── mcp-troubleshooting.md  # Common issues
```

### 4.3 Testing Framework
- Unit test templates for new servers
- Integration test harness
- Performance benchmarks
- Manifest validation tests
- CLI command tests

### 4.4 Migration Guide
- Step-by-step migration from current system
- Automated migration script where possible
- Rollback procedures
- FAQ and troubleshooting

### Deliverables:
- [ ] Working scaffolding tool
- [ ] Complete documentation set
- [ ] Test templates and harness
- [ ] Migration guide and scripts

## Implementation Timeline

### Week 1 (Phase 0): Foundation
- Monday-Tuesday: Environment and permissions
- Wednesday-Thursday: Schema definitions
- Friday: Caching and atomic operations

### Week 2 (Phase 1): Registry System  
- Monday-Tuesday: Registry structure
- Wednesday: Configuration layering
- Thursday-Friday: Docker integration

### Week 3 (Phase 2): CLI Implementation
- Monday-Tuesday: Core commands
- Wednesday-Thursday: Developer commands
- Friday: Testing and refinement

### Week 4 (Phase 3.1-3.3): Core Servers
- Monday: Migrate Codex
- Tuesday-Wednesday: Qdrant server
- Thursday-Friday: CodeQuery server

### Week 5 (Phase 3.4-3.5): Additional Servers
- Monday-Tuesday: LLM wrapper
- Wednesday-Thursday: Docker management
- Friday: Integration testing

### Week 6 (Phase 4): Polish
- Monday-Tuesday: Scaffolding tool
- Wednesday-Thursday: Documentation
- Friday: Final testing and release prep

## Success Metrics

1. **Performance**
   - Startup overhead < 100ms
   - Command response < 200ms
   - Cache hit rate > 90%

2. **Reliability**
   - Zero data loss during operations
   - Graceful handling of all errors
   - Atomic operations with rollback

3. **Usability**
   - New server creation < 5 minutes
   - Clear error messages
   - Comprehensive help system

4. **Compatibility**
   - All existing features preserved
   - Smooth migration path
   - Backward compatibility maintained

## Risk Mitigation

1. **Migration Risks**
   - Automated backup before migration
   - Rollback script provided
   - Staged rollout option

2. **Performance Risks**
   - Aggressive caching strategy
   - Lazy loading where possible
   - Performance benchmarks in CI

3. **Security Risks**
   - Strict permission model
   - Input validation everywhere
   - Regular security audits

## Appendix: File Structure

```
/claudex/
├── schemas/
│   ├── manifest-v1.schema.json
│   ├── registry-v1.schema.json
│   └── config-v1.schema.json
├── scripts/
│   ├── mcp-utils.sh
│   ├── mcp-config.sh
│   ├── mcp-atomic.sh
│   ├── validate-schema.sh
│   └── migrate-mcp.sh
├── templates/
│   └── mcp-server/
│       ├── manifest.json.tmpl
│       ├── index.js.tmpl
│       ├── package.json.tmpl
│       └── README.md.tmpl
├── mcp-servers/
│   ├── core/
│   │   └── codex/
│   ├── qdrant/
│   ├── codequery/
│   ├── llm-wrapper/
│   ├── docker-mgmt/
│   └── examples/
├── tests/
│   ├── unit/
│   ├── integration/
│   └── performance/
└── docs/
    ├── mcp-implementation-plan.md
    ├── mcp-development.md
    ├── mcp-architecture.md
    └── mcp-api-reference.md
```

---

This implementation plan provides a clear, phased approach to building the extensible MCP architecture for Claudex. Each phase builds upon the previous one, with specific deliverables and success criteria.