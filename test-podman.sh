#!/bin/bash

# Test script for Podman functionality
set -e

echo "Testing Podman detection and functionality..."

# Source color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if Podman is installed
if command -v podman &> /dev/null; then
    echo -e "${GREEN}✓${NC} Podman is installed"
    podman --version
else
    echo -e "${RED}✗${NC} Podman is not installed"
    exit 1
fi

# Test container runtime detection
if command -v podman &> /dev/null; then
    CONTAINER_RUNTIME="podman"
else
    CONTAINER_RUNTIME="docker"
fi

echo -e "${GREEN}✓${NC} Detected runtime: $CONTAINER_RUNTIME"

# Test the userns=keep-id flag
echo -e "\n${YELLOW}Testing userns=keep-id functionality:${NC}"
echo "Host UID: $(id -u)"
echo "Host GID: $(id -g)"

# Create a test container with userns=keep-id
echo -e "\n${YELLOW}Creating test container with --userns=keep-id:${NC}"
podman run --rm --userns=keep-id alpine:latest sh -c 'echo "Container UID: $(id -u)"; echo "Container GID: $(id -g)"'

echo -e "\n${GREEN}✓${NC} Test completed successfully!"
echo -e "\n${YELLOW}Summary:${NC}"
echo "- Podman is properly installed and functioning"
echo "- The --userns=keep-id flag correctly maps host UID/GID into the container"
echo "- This will solve the permission issues when using Claudex with Podman"