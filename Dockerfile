FROM node:22

# Install sudo and Python dependencies
RUN apt-get update && apt-get install -y \
    sudo vim strace jq \
    python3 python3-pip python3-venv git \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code @openai/codex

# Create user and give passwordless sudo
RUN useradd -ms /bin/bash claudex && \
    echo 'claudex ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/claudex && \
    chmod 0440 /etc/sudoers.d/claudex

# Set up CodeQuery in a system-wide location
RUN mkdir -p /opt/codequery && \
    python3 -m venv /opt/codequery/venv && \
    /opt/codequery/venv/bin/pip install --upgrade pip && \
    cd /opt/codequery && \
    git clone https://github.com/stevenbecht/codequery.git repo && \
    /opt/codequery/venv/bin/pip install -e ./repo && \
    chown -R claudex:claudex /opt/codequery

# Copy update script
COPY scripts/update-packages.sh /usr/local/bin/update-packages
RUN chmod +x /usr/local/bin/update-packages

# Copy qdrant manager script
COPY scripts/qdrant-manager.sh /usr/local/bin/qdrant-manager
RUN chmod +x /usr/local/bin/qdrant-manager

# Copy codequery wrapper script
COPY scripts/cq-wrapper.sh /usr/local/bin/cq
RUN chmod +x /usr/local/bin/cq

# Set up MCP directory structure
ENV CLAUDEX_MCP_REGISTRY=/opt/mcp-servers
RUN mkdir -p ${CLAUDEX_MCP_REGISTRY}/{core,installed,disabled} && \
    chmod 755 ${CLAUDEX_MCP_REGISTRY} ${CLAUDEX_MCP_REGISTRY}/{core,installed,disabled} && \
    echo '{"version": "1.0.0", "servers": {}}' > ${CLAUDEX_MCP_REGISTRY}/registry.json && \
    chmod 644 ${CLAUDEX_MCP_REGISTRY}/registry.json && \
    chown -R claudex:claudex ${CLAUDEX_MCP_REGISTRY}

# Set up MCP Codex Server in new structure
COPY mcp-codex-server ${CLAUDEX_MCP_REGISTRY}/core/codex
RUN cd ${CLAUDEX_MCP_REGISTRY}/core/codex && \
    npm install && \
    chmod +x index.js && \
    chown -R claudex:claudex ${CLAUDEX_MCP_REGISTRY}/core/codex

# Copy MCP utilities
COPY scripts/mcp-utils.sh /opt/mcp-utils.sh
RUN chmod +x /opt/mcp-utils.sh

# Copy MCP codex wrapper script
COPY scripts/mcp-codex-wrapper.sh /usr/local/bin/mcp-codex-wrapper
RUN chmod +x /usr/local/bin/mcp-codex-wrapper

# Copy entrypoint script
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Copy Qdrant status helper
COPY scripts/qdrant-status.sh /usr/local/bin/qdrant-status
RUN chmod +x /usr/local/bin/qdrant-status

USER claudex
WORKDIR /home/claudex

# Create aliases for easy commands
RUN echo 'alias update="update-packages"' >> /home/claudex/.bashrc && \
    echo 'alias qdrant="qdrant-manager"' >> /home/claudex/.bashrc && \
    echo '' >> /home/claudex/.bashrc && \
    echo '# Qdrant shortcuts' >> /home/claudex/.bashrc && \
    echo 'alias qs="qdrant-manager status"' >> /home/claudex/.bashrc && \
    echo 'alias qstart="qdrant-manager start"' >> /home/claudex/.bashrc && \
    echo 'alias qstop="qdrant-manager stop"' >> /home/claudex/.bashrc && \
    echo 'alias qlogs="qdrant-manager logs -f"' >> /home/claudex/.bashrc && \
    echo 'alias qstatus="qdrant-status"' >> /home/claudex/.bashrc && \
    echo '' >> /home/claudex/.bashrc && \
    echo '# Auto-start Qdrant on login (unless disabled)' >> /home/claudex/.bashrc && \
    echo '# Set CLAUDEX_AUTO_START_QDRANT=false to disable auto-start' >> /home/claudex/.bashrc && \
    echo '# Set CLAUDEX_QDRANT_STARTUP_QUIET=false to see startup messages' >> /home/claudex/.bashrc && \
    echo 'if [ "${CLAUDEX_AUTO_START_QDRANT:-true}" = "true" ]; then' >> /home/claudex/.bashrc && \
    echo '  # Log startup attempt' >> /home/claudex/.bashrc && \
    echo '  mkdir -p ~/.qdrant' >> /home/claudex/.bashrc && \
    echo '  echo "[$(date)] Attempting Qdrant auto-start via .bashrc" >> ~/.qdrant/startup.log' >> /home/claudex/.bashrc && \
    echo '  ' >> /home/claudex/.bashrc && \
    echo '  # Start Qdrant with optional quiet mode' >> /home/claudex/.bashrc && \
    echo '  if [ "${CLAUDEX_QDRANT_STARTUP_QUIET:-true}" = "false" ]; then' >> /home/claudex/.bashrc && \
    echo '    if qdrant-manager start; then' >> /home/claudex/.bashrc && \
    echo '      echo "[$(date)] Qdrant started successfully via .bashrc" >> ~/.qdrant/startup.log' >> /home/claudex/.bashrc && \
    echo '    else' >> /home/claudex/.bashrc && \
    echo '      echo "[$(date)] Qdrant startup failed or already running via .bashrc" >> ~/.qdrant/startup.log' >> /home/claudex/.bashrc && \
    echo '    fi' >> /home/claudex/.bashrc && \
    echo '  else' >> /home/claudex/.bashrc && \
    echo '    if qdrant-manager start >/dev/null 2>&1; then' >> /home/claudex/.bashrc && \
    echo '      echo "[$(date)] Qdrant started successfully via .bashrc (quiet mode)" >> ~/.qdrant/startup.log' >> /home/claudex/.bashrc && \
    echo '    else' >> /home/claudex/.bashrc && \
    echo '      echo "[$(date)] Qdrant startup failed or already running via .bashrc (quiet mode)" >> ~/.qdrant/startup.log' >> /home/claudex/.bashrc && \
    echo '    fi' >> /home/claudex/.bashrc && \
    echo '  fi' >> /home/claudex/.bashrc && \
    echo 'fi' >> /home/claudex/.bashrc

# Configure npm to use user-local path
#RUN mkdir -p /home/claudex/.npm-global && \
#    npm config set prefix '/home/claudex/.npm-global' && \
#    echo 'export PATH=$HOME/.npm-global/bin:$PATH' >> /home/claudex/.bashrc

# Ensure the PATH is available for non-interactive shells (Docker RUN)
#ENV PATH="/home/claudex/.npm-global/bin:$PATH"

# Install binaries globally without root
#RUN npm install -g @anthropic-ai/claude-code @openai/codex

# Use entrypoint to ensure Qdrant starts regardless of how container is entered
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["bash", "--login"]
