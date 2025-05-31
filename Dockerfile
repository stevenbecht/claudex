FROM node

RUN npm install -g @anthropic-ai/claude-code @openai/codex

RUN useradd -ms /bin/bash claudex

USER claudex
WORKDIR /home/claudex

CMD ["bash", "--login"]
