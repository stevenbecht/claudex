# AGENTS.md

This file provides context and guidance for AI agents (like Codex) when reviewing code and interactions in the Claudex project.

## Table of Contents

- [Project Overview](#project-overview)
- [Code Review Guidelines](#code-review-guidelines)
  - [Architecture Principles](#architecture-principles)
  - [Code Quality Standards](#code-quality-standards)
  - [Key Components to Review](#key-components-to-review)
- [Code Style & Testing](#code-style--testing)
- [Contribution Workflow](#contribution-workflow)
- [Review Checklist](#review-checklist)
- [Common Issues to Watch For](#common-issues-to-watch-for)
- [Integration Testing Scenarios](#integration-testing-scenarios)
- [Performance Considerations](#performance-considerations)
- [Security Review Points](#security-review-points)

## Project Overview

Claudex is a Docker-based development environment manager that creates isolated, project-specific containers with AI coding assistants pre-installed. It follows a container-per-project architecture where each project gets its own named container with persistent environment data.

For detailed usage instructions, run `claudex help` or refer to the [CLAUDE.md](./CLAUDE.md) file.

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

## Code Style & Testing

### Shell Script Standards
- Use `shellcheck` to validate bash scripts for common issues
- Follow consistent indentation (2 spaces preferred)
- Quote all variables to handle spaces properly: `"$var"` not `$var`
- Use `set -euo pipefail` for error handling in scripts
- Prefer `[[ ]]` over `[ ]` for conditionals in bash

### Testing Requirements
- **Unit Tests**: Not currently implemented, but shell scripts can be tested with `bats` (Bash Automated Testing System)
- **Integration Tests**: Test the full container lifecycle:
  ```bash
  # Test creating a new project
  ./claudex.sh start testproject --dir /tmp/testproject
  
  # Test reconnecting to existing project
  ./claudex.sh stop testproject
  ./claudex.sh start testproject
  
  # Test cleanup
  ./claudex.sh cleanup testproject
  ```
- **Build Tests**: Verify Docker image builds successfully:
  ```bash
  make clean && make build
  ```

### Pre-Review Validation
Before submitting changes, run:
```bash
# Validate shell scripts
shellcheck claudex.sh

# Test Docker build
make rebuild

# Run basic integration test
./claudex.sh help
```

## Contribution Workflow

### Branch Naming Convention
- Feature branches: `feature/description-of-feature`
- Bug fixes: `fix/issue-description`
- Documentation: `docs/what-is-being-documented`

### Commit Message Format
Follow conventional commits:
```
type(scope): brief description

Longer explanation if needed

Fixes #123
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

### Pull Request Process
1. Create feature branch from `main`
2. Make changes following code style guidelines
3. Test changes thoroughly (see Testing Requirements)
4. Update documentation if needed
5. Submit PR with clear description of changes
6. Ensure all review checklist items are addressed

### Pre-commit Checks
Consider adding these checks before committing:
- Run `shellcheck` on modified shell scripts
- Verify `make build` succeeds if Dockerfile changed
- Update CLAUDE.md if adding new commands/features

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
   - Validate upgrade backup/restore mechanism works correctly

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

4. **Container Upgrade After Image Rebuild**
   ```bash
   make rebuild  # Rebuild the Docker image
   claudex upgrade myapp  # Upgrade single container
   claudex upgrade --all  # Upgrade all containers
   # Note: Upgrade creates backup and restores on failure
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