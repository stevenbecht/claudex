# AGENTS.md

This file provides context and guidance for AI agents (like Codex) when reviewing code and interactions in the Claudex project.

## Project Overview

Claudex is a Docker-based development environment manager that creates isolated, project-specific containers with AI coding assistants pre-installed. It follows a container-per-project architecture where each project gets its own named container with persistent environment data.

## Code Review Guidelines

When reviewing changes or interactions in this project, consider:

### Architecture Principles
- **Container Isolation**: Each project must run in its own Docker container
- **Persistent State**: Environment data should persist between container restarts
- **Security**: Containers run as non-root user `claudex`
- **Naming Convention**: Container names follow pattern `claudex_[project]`

### Code Quality Standards
- **Error Handling**: All commands should include proper error checking and user feedback
- **User Experience**: Clear, color-coded status messages for all operations
- **Safety**: Destructive operations require confirmation prompts
- **Documentation**: Commands should be self-documenting with help text

### Key Components to Review

1. **claudex.sh** - Main entry point script
   - Command parsing and validation
   - Container lifecycle management
   - Error handling and user feedback
   - Safety checks for destructive operations

2. **Dockerfile** - Container image definition
   - Base image selection and security
   - Package installation efficiency
   - User permissions setup
   - Pre-installed tools configuration

3. **Makefile** - Build automation
   - Build targets correctness
   - Dependency management
   - Clean operations completeness

## Review Checklist

When reviewing changes, verify:

- [ ] Container naming follows `claudex_[project]` pattern
- [ ] Persistent data stored in `~/claudex/[project]`
- [ ] Project code mounted at `/[project]` in container
- [ ] Error messages are clear and actionable
- [ ] Confirmation prompts for destructive operations
- [ ] Commands provide appropriate feedback
- [ ] Security best practices (non-root user, no hardcoded secrets)
- [ ] Documentation updated for new features

## Common Issues to Watch For

1. **Container State Management**
   - Ensure containers can be stopped/started without data loss
   - Verify cleanup operations don't remove active containers
   - Check that restart operations handle both running and stopped states

2. **Path Handling**
   - Absolute vs relative path resolution
   - Proper escaping for paths with spaces
   - Consistent path mounting between host and container

3. **Error Conditions**
   - Docker daemon not running
   - Container name conflicts
   - Missing project directories
   - Permission issues

## Integration Testing Scenarios

Consider these scenarios when evaluating changes:

1. **New Project Setup**
   ```bash
   claudex start myapp --dir ~/projects/myapp
   ```

2. **Reattaching to Existing Project**
   ```bash
   claudex stop myapp
   claudex start myapp  # Should reconnect, not recreate
   ```

3. **Multiple Project Management**
   ```bash
   claudex status  # Should list all projects
   claudex cleanup --all  # Should only remove stopped containers
   ```

## Performance Considerations

- Container startup time should be minimal
- Build process should use Docker layer caching effectively
- Commands should respond quickly with appropriate feedback
- Log output should be streamlined and relevant

## Security Review Points

- No credentials or secrets in code or Docker images
- Proper file permissions in containers
- Network isolation between project containers
- Safe handling of user-provided paths and project names