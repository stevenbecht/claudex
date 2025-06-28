#!/bin/bash
# Test script for MCP registry system

set -euo pipefail

# Source MCP utilities
source /claudex/scripts/mcp-utils.sh

echo "=== Testing MCP Registry System ==="
echo

# Test 1: Check registry path
echo "1. Testing registry path..."
registry_path=$(get_mcp_registry)
echo "   Registry path: $registry_path"
echo

# Test 2: Check if registry exists
echo "2. Checking registry existence..."
if check_mcp_registry; then
  echo "   ✓ Registry exists and is readable"
else
  echo "   ✗ Registry check failed"
  exit 1
fi
echo

# Test 3: List available servers
echo "3. Listing available MCP servers..."
servers=$(list_mcp_servers)
if [ -n "$servers" ]; then
  echo "$servers" | while read -r server; do
    echo "   - $server"
  done
else
  echo "   No servers found"
fi
echo

# Test 4: Validate Codex server
echo "4. Validating Codex server..."
if validate_mcp_server "$registry_path/core/codex"; then
  echo "   ✓ Codex server validation passed"
else
  echo "   ✗ Codex server validation failed"
fi
echo

# Test 5: Get Codex metadata
echo "5. Getting Codex server metadata..."
if metadata=$(get_mcp_server_metadata "codex"); then
  echo "   ✓ Successfully retrieved metadata:"
  echo "$metadata" | jq '.metadata'
else
  echo "   ✗ Failed to get metadata"
fi
echo

# Test 6: Generate MCP configuration
echo "6. Generating MCP configuration..."
test_config="/tmp/test-mcp.json"
if generate_mcp_config "$test_config" >/dev/null; then
  echo "   ✓ Configuration generated successfully:"
  cat "$test_config" | jq '.'
  rm -f "$test_config"
else
  echo "   ✗ Failed to generate configuration"
fi
echo

# Test 7: Test caching
echo "7. Testing cache system..."
if update_mcp_cache >/dev/null; then
  echo "   ✓ Cache updated successfully"
  if is_cache_valid; then
    echo "   ✓ Cache is valid"
  fi
else
  echo "   ✗ Cache update failed"
fi
echo

echo "=== Registry System Test Complete ==="