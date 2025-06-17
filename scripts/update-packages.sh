#!/bin/bash

# Update claude-code, codex, and codequery packages
# This script should be run inside the container

set -e

echo "Updating AI coding assistant packages..."

# Update npm packages globally with sudo
echo "→ Updating Node.js packages..."
sudo npm update -g @anthropic-ai/claude-code @openai/codex

# Update CodeQuery from git
echo ""
echo "→ Updating CodeQuery..."
cd /opt/codequery/repo
git pull origin main
/opt/codequery/venv/bin/pip install -e .

echo ""
echo "✓ All packages updated successfully"

# Show installed versions
echo ""
echo "Installed versions:"
echo "Node.js packages:"
npm list -g @anthropic-ai/claude-code @openai/codex --depth=0

echo ""
echo "CodeQuery:"
/opt/codequery/venv/bin/pip show codequery | grep -E "^(Name|Version):"