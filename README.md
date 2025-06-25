# Claudex 🐳🤖

> Isolated, AI-powered development environments for every project

Claudex is a Docker-based development environment manager that creates isolated, project-specific containers with AI coding assistants pre-installed. Each project gets its own persistent environment with tools like Claude Code, OpenAI Codex, vector search capabilities, and more - all accessible through simple commands.

## 🎯 Why Claudex?

Traditional development environments often suffer from:
- **Dependency Hell**: Conflicting package versions between projects
- **Setup Fatigue**: Hours spent configuring tools for each project
- **AI Tool Fragmentation**: Multiple tools that don't work well together
- **Environment Drift**: "Works on my machine" syndrome

Claudex solves these problems by providing:
- **Complete Isolation**: Each project gets its own container
- **AI-First Design**: All AI tools pre-configured and ready to use
- **One Command Setup**: From zero to coding in seconds
- **Reproducible Environments**: Same setup every time, on any machine

## ✨ Key Features

- **🔒 Project Isolation**: Each project runs in its own container with persistent state
- **🤖 AI-Ready**: Pre-installed AI coding assistants (Claude Code, OpenAI Codex)
- **🔍 Semantic Code Search**: Built-in vector database (Qdrant) with CodeQuery for natural language code search
- **🚀 Zero Config**: Automatic setup of MCP servers, environment variables, and tools
- **💾 Persistent State**: Project data and configurations survive container restarts
- **🔧 Developer Friendly**: Common tools pre-installed (Node.js, Python, Git, etc.)
- **🎯 Simple CLI**: Intuitive commands for container lifecycle management

## 📋 Prerequisites

### Required
- Docker installed and running (Docker Desktop or Docker Engine)
- Linux or macOS operating system
- At least 4GB of free disk space for the base image

### Recommended
- 8GB+ RAM for optimal performance
- 10GB+ free disk space for multiple projects
- Fast internet connection for pulling Docker images

### For AI Features
- **OpenAI API key**: Required for CodeQuery and Codex features
- **Anthropic API key**: Optional, for enhanced Claude Code features

## 🚀 Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd claudex

# Initial setup (builds Docker image and creates symlinks)
./claudex.sh init

# Start a new project environment
claudex start myproject --dir ~/projects/myproject

# That's it! You're now in an isolated environment with AI tools ready to use
```

## 📖 Usage

### Managing Projects

```bash
# Start a new project (first time)
claudex start myapp --dir ~/projects/myapp

# Start with port mappings (host:container)
claudex start myapp --dir ~/projects/myapp --port 8080,3000:3000

# Reattach to existing project
claudex start myapp

# Stop a running container (keeps it for later)
claudex stop myapp

# Restart a container
claudex restart myapp

# Remove a container completely
claudex remove myapp

# View all projects status
claudex status

# View specific project status
claudex status myapp

# View container logs
claudex logs myapp
claudex logs myapp --follow
```

### Container Maintenance

```bash
# Rebuild the Docker image
make rebuild

# Upgrade containers to latest image
claudex upgrade myapp        # Single project
claudex upgrade --all        # All containers

# Clean up stopped containers
claudex cleanup myapp        # Single project
claudex cleanup --all        # All stopped containers
```

### Using AI Tools

#### CodeQuery - Natural Language Code Search

```bash
# Inside a container
# Set your OpenAI API key
export OPENAI_API_KEY='your-api-key'
# Or save it in .env file
echo "OPENAI_API_KEY=your-api-key" >> .env

# Start Qdrant (usually auto-starts)
qstart

# Embed your codebase
cq embed /myproject --project myproject

# Search with natural language
cq search "authentication logic" --project myproject

# Interactive chat with code context
cq chat --project myproject

# View embedding statistics
cq stats --project myproject
```

#### MCP Codex Server

The MCP Codex server is automatically configured. In Claude Code, you can use:
- `codex_review` - Request code reviews
- `codex_consult` - Get implementation guidance
- `codex_status` - Check project status
- `codex_history` - View past sessions

### Vector Database (Qdrant)

Qdrant starts automatically when you enter a container. Manual controls:

```bash
# Inside container shortcuts
qstart   # Start Qdrant
qstop    # Stop Qdrant
qs       # Check status
qlogs    # Follow logs
qstatus  # Check auto-start config

# From host
claudex qdrant myapp start
claudex qdrant myapp stop
claudex qdrant myapp status
claudex qdrant myapp logs
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│              Host System                     │
│                                              │
│  ~/projects/myapp ──┐                        │
│                     │ mounted to             │
│  ~/claudex/myapp ───┼──────┐                │
│                     │      │                 │
└─────────────────────┼──────┼─────────────────┘
                      │      │
┌─────────────────────┼──────┼─────────────────┐
│  Docker Container   │      │                 │
│  (claudex_myapp)    ▼      ▼                 │
│                 /myapp  /home/claudex        │
│                                              │
│  Pre-installed:                              │
│  - Node.js 22 + npm packages                 │
│  - Python 3 + CodeQuery                      │
│  - Qdrant Vector DB                          │
│  - MCP Codex Server                          │
│  - Claude Code & OpenAI Codex                │
│                                              │
│  Running as: claudex (non-root user)         │
└──────────────────────────────────────────────┘
```

### Key Design Decisions

- **Container-per-project**: Complete isolation between projects
- **Persistent volumes**: Project data survives container lifecycle
- **Non-root execution**: Security-first approach with sudo available
- **Auto-configuration**: Tools configure themselves on startup
- **Quiet by default**: Docker-friendly output, verbose when needed

## 🛠️ Advanced Usage

### Environment Variables

Create a `.env` file in your project or home directory:
```bash
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
CLAUDEX_AUTO_START_QDRANT=true
CLAUDEX_QDRANT_STARTUP_QUIET=true
```

### Custom Port Mappings

```bash
# Multiple ports
claudex start myapp --port 8080,3000:3000,5432:5432

# Format: [host_port]:[container_port]
# If only one port specified, maps to same port on host
```

### Makefile Commands

```bash
make build          # Build Docker image
make rebuild        # Force rebuild from scratch
make clean          # Remove Docker image
make push           # Push to registry (if configured)
make help           # Show all commands
```

## 🔧 Troubleshooting

### Qdrant Issues
```bash
# Check auto-start logs
qstatus

# View detailed startup logs
cat ~/.qdrant/startup.log

# Manually start if needed
qstart
```

### Container Issues
```bash
# Check container logs
claudex logs myapp

# Force remove stuck container
docker rm -f claudex_myapp

# Rebuild image if corrupted
make clean && make build
```

### Permission Issues
- Containers run as user `claudex` with UID 1000
- Use `sudo` inside container if needed (no password required)
- If you encounter permission issues, ensure your host user has access to the project directory

## 🔐 Security Considerations

- **API Keys**: Store sensitive keys in `.env` files, never commit them to version control
- **Container Isolation**: Each project runs in its own container for security
- **Non-root User**: Containers run as non-root user by default
- **Network Isolation**: Containers only expose explicitly mapped ports
- **Volume Mounts**: Only specified directories are accessible to containers

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly with `make rebuild` and container testing
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Guidelines

- Follow existing code style and conventions
- Update CLAUDE.md if adding new features
- Test with multiple projects before submitting
- Document any new commands or features

## 📄 License

This project is open source. License details will be added soon.

## 🙏 Acknowledgments

- Built on top of excellent tools like Docker, Node.js, and Python
- Integrates AI assistants from Anthropic and OpenAI
- Uses Qdrant for powerful vector search capabilities

## 🐛 Reporting Issues

Found a bug or have a suggestion? Please open an issue on GitHub with:
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- System information (OS, Docker version)

---

<p align="center">
Made with ❤️ for developers who love isolated environments and AI assistance
</p>