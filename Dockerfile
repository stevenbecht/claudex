FROM node

# Install sudo and Python dependencies
RUN apt-get update && apt-get install -y \
    sudo vim strace \
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

# Set up MCP Codex Server
COPY mcp-codex-server /opt/mcp-codex-server
RUN cd /opt/mcp-codex-server && \
    npm install && \
    chmod +x index.js && \
    chown -R claudex:claudex /opt/mcp-codex-server

# Copy MCP codex wrapper script
COPY scripts/mcp-codex-wrapper.sh /usr/local/bin/mcp-codex-wrapper
RUN chmod +x /usr/local/bin/mcp-codex-wrapper

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
    echo 'alias qlogs="qdrant-manager logs -f"' >> /home/claudex/.bashrc

# Configure npm to use user-local path
#RUN mkdir -p /home/claudex/.npm-global && \
#    npm config set prefix '/home/claudex/.npm-global' && \
#    echo 'export PATH=$HOME/.npm-global/bin:$PATH' >> /home/claudex/.bashrc

# Ensure the PATH is available for non-interactive shells (Docker RUN)
#ENV PATH="/home/claudex/.npm-global/bin:$PATH"

# Install binaries globally without root
#RUN npm install -g @anthropic-ai/claude-code @openai/codex

CMD ["bash", "--login"]
