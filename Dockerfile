FROM node

# Install sudo
RUN apt-get update && apt-get install -y sudo vim strace

RUN npm install -g @anthropic-ai/claude-code @openai/codex

# Create user and give passwordless sudo
RUN useradd -ms /bin/bash claudex && \
    echo 'claudex ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/claudex && \
    chmod 0440 /etc/sudoers.d/claudex

USER claudex
WORKDIR /home/claudex

# Configure npm to use user-local path
#RUN mkdir -p /home/claudex/.npm-global && \
#    npm config set prefix '/home/claudex/.npm-global' && \
#    echo 'export PATH=$HOME/.npm-global/bin:$PATH' >> /home/claudex/.bashrc

# Ensure the PATH is available for non-interactive shells (Docker RUN)
#ENV PATH="/home/claudex/.npm-global/bin:$PATH"

# Install binaries globally without root
#RUN npm install -g @anthropic-ai/claude-code @openai/codex

CMD ["bash", "--login"]
