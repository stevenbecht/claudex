#!/bin/bash

# Quick status check for Qdrant auto-start feature

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}Qdrant Auto-Start Status${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check environment variables
echo -e "\n${BLUE}Configuration:${NC}"
echo -e "  CLAUDEX_AUTO_START_QDRANT: ${CLAUDEX_AUTO_START_QDRANT:-true} (default: true)"
echo -e "  CLAUDEX_QDRANT_STARTUP_QUIET: ${CLAUDEX_QDRANT_STARTUP_QUIET:-true} (default: true)"
echo -e "  QDRANT_PORT: ${QDRANT_PORT:-6333} (default: 6333)"

# Check if startup log exists
if [ -f ~/.qdrant/startup.log ]; then
  echo -e "\n${BLUE}Recent startup attempts:${NC}"
  tail -n 10 ~/.qdrant/startup.log | sed 's/^/  /'
else
  echo -e "\n${YELLOW}No startup log found${NC}"
fi

# Check current Qdrant status
echo -e "\n${BLUE}Current status:${NC}"
qdrant-manager status | sed 's/^/  /'

# Tips
echo -e "\n${BLUE}Tips:${NC}"
echo "  • To disable auto-start: export CLAUDEX_AUTO_START_QDRANT=false"
echo "  • To see startup messages: export CLAUDEX_QDRANT_STARTUP_QUIET=false"
echo "  • To check full logs: qdrant-manager logs"
echo "  • To manually start: qstart or qdrant-manager start"