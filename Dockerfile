FROM node

RUN useradd -ms /bin/bash claudex

USER claudex
WORKDIR /home/claudex

# Configure npm to use user directory for global installs
RUN mkdir -p /home/claudex/.npm-global && \
    npm config set prefix '/home/claudex/.npm-global' && \
    echo 'export PATH=/home/claudex/.npm-global/bin:$PATH' >> ~/.bashrc

# Install packages as claudex user
RUN npm install -g @anthropic-ai/claude-code @openai/codex

CMD ["bash", "--login"]