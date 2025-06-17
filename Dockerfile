FROM node

# Install sudo
RUN apt-get update && apt-get install -y sudo vim strace

RUN npm install -g @anthropic-ai/claude-code @openai/codex

# Create user and give passwordless sudo
RUN useradd -ms /bin/bash claudex && \
    echo 'claudex ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/claudex && \
    chmod 0440 /etc/sudoers.d/claudex

# Copy update script
COPY scripts/update-packages.sh /usr/local/bin/update-packages
RUN chmod +x /usr/local/bin/update-packages

# Copy qdrant manager script
COPY scripts/qdrant-manager.sh /usr/local/bin/qdrant-manager
RUN chmod +x /usr/local/bin/qdrant-manager

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
