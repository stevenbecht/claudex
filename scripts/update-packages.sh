#!/bin/bash

# Update claude-code and codex packages
# This script should be run inside the container

set -e

echo "Updating AI coding assistant packages..."

# Update npm packages globally with sudo
sudo npm update -g @anthropic-ai/claude-code @openai/codex

echo "✓ Packages updated successfully"

# Show installed versions
echo ""
echo "Installed versions:"
npm list -g @anthropic-ai/claude-code @openai/codex --depth=0