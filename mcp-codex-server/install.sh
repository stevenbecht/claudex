#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Installing MCP Codex Server...${NC}"

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo -e "${RED}Error: package.json not found. Please run this script from the mcp-codex-server directory.${NC}"
    exit 1
fi

# Install npm dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
npm install

# Make the server executable
chmod +x index.js

# Check for OPENAI_API_KEY
if [ -z "$OPENAI_API_KEY" ] && [ ! -f ".env" ]; then
    echo -e "${YELLOW}Warning: OPENAI_API_KEY not found in environment.${NC}"
    echo "Please set it in your environment or create a .env file:"
    echo "  echo \"OPENAI_API_KEY=your-key-here\" >> .env"
fi

# Create a global symlink (optional)
if [ -w "/usr/local/bin" ]; then
    ln -sf "$(pwd)/index.js" /usr/local/bin/mcp-codex-server
    echo -e "${GREEN}Created global symlink at /usr/local/bin/mcp-codex-server${NC}"
fi

echo -e "${GREEN}✓ MCP Codex Server installed successfully!${NC}"
echo ""
echo "To use with Claude Desktop or other MCP clients, add to your configuration:"
echo '{'
echo '  "mcpServers": {'
echo '    "codex": {'
echo '      "command": "node",'
echo "      \"args\": [\"$(pwd)/index.js\"]"
echo '    }'
echo '  }'
echo '}'