#!/bin/bash
# MCP (Model Context Protocol) utility functions for Claudex
# This script provides common functions for MCP server management

set -euo pipefail

# Default MCP registry location (can be overridden by CLAUDEX_MCP_REGISTRY env var)
DEFAULT_MCP_REGISTRY="/opt/mcp-servers"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the MCP registry path
get_mcp_registry() {
  echo "${CLAUDEX_MCP_REGISTRY:-$DEFAULT_MCP_REGISTRY}"
}

# Get the MCP cache directory
get_mcp_cache_dir() {
  echo "${HOME}/.cache/claudex/mcp"
}

# Get the MCP config directory for a project
get_mcp_project_config_dir() {
  local project="${1:-}"
  if [ -z "$project" ]; then
    echo ""
    return 1
  fi
  echo "${HOME}/claudex/${project}/.mcp"
}

# Check if MCP registry exists and is readable
check_mcp_registry() {
  local registry=$(get_mcp_registry)
  
  if [ ! -d "$registry" ]; then
    echo -e "${RED}Error:${NC} MCP registry not found at $registry" >&2
    echo "Please ensure the Claudex image is built with MCP support." >&2
    return 1
  fi
  
  if [ ! -r "$registry" ]; then
    echo -e "${RED}Error:${NC} MCP registry at $registry is not readable" >&2
    return 1
  fi
  
  return 0
}

# Create MCP directories with proper permissions
create_mcp_directories() {
  local registry=$(get_mcp_registry)
  local cache_dir=$(get_mcp_cache_dir)
  
  # Create registry structure
  mkdir -p "$registry"/{core,installed,disabled}
  chmod 755 "$registry" "$registry"/{core,installed,disabled}
  
  # Create cache directory
  mkdir -p "$cache_dir"
  chmod 755 "$cache_dir"
  
  # Create registry.json if it doesn't exist
  if [ ! -f "$registry/registry.json" ]; then
    echo '{"version": "1.0.0", "servers": {}}' > "$registry/registry.json"
    chmod 644 "$registry/registry.json"
  fi
}

# Validate MCP server structure
validate_mcp_server() {
  local server_path="${1:-}"
  
  if [ -z "$server_path" ] || [ ! -d "$server_path" ]; then
    echo -e "${RED}Error:${NC} Invalid server path: $server_path" >&2
    return 1
  fi
  
  # Check for required files
  local required_files=("manifest.json")
  for file in "${required_files[@]}"; do
    if [ ! -f "$server_path/$file" ]; then
      echo -e "${RED}Error:${NC} Missing required file: $file" >&2
      return 1
    fi
  done
  
  # Validate manifest.json structure (basic check)
  if ! jq -e . "$server_path/manifest.json" >/dev/null 2>&1; then
    echo -e "${RED}Error:${NC} Invalid JSON in manifest.json" >&2
    return 1
  fi
  
  # Check for required manifest fields
  local required_fields=("apiVersion" "metadata.name" "server.command")
  for field in "${required_fields[@]}"; do
    if ! jq -e ".$field" "$server_path/manifest.json" >/dev/null 2>&1; then
      echo -e "${RED}Error:${NC} Missing required field in manifest: $field" >&2
      return 1
    fi
  done
  
  return 0
}

# Get list of available MCP servers
list_mcp_servers() {
  local registry=$(get_mcp_registry)
  local server_list=()
  
  # Check core servers
  if [ -d "$registry/core" ]; then
    for server_dir in "$registry/core"/*; do
      if [ -d "$server_dir" ] && validate_mcp_server "$server_dir" >/dev/null 2>&1; then
        server_list+=("core/$(basename "$server_dir")")
      fi
    done
  fi
  
  # Check installed servers
  if [ -d "$registry/installed" ]; then
    for server_dir in "$registry/installed"/*; do
      if [ -d "$server_dir" ] && validate_mcp_server "$server_dir" >/dev/null 2>&1; then
        server_list+=("installed/$(basename "$server_dir")")
      fi
    done
  fi
  
  printf '%s\n' "${server_list[@]}"
}

# Get MCP server metadata
get_mcp_server_metadata() {
  local server_name="${1:-}"
  local registry=$(get_mcp_registry)
  
  # Try to find the server in core or installed
  local server_path=""
  if [ -d "$registry/core/$server_name" ]; then
    server_path="$registry/core/$server_name"
  elif [ -d "$registry/installed/$server_name" ]; then
    server_path="$registry/installed/$server_name"
  else
    echo -e "${RED}Error:${NC} Server not found: $server_name" >&2
    return 1
  fi
  
  if ! validate_mcp_server "$server_path" >/dev/null 2>&1; then
    return 1
  fi
  
  cat "$server_path/manifest.json"
}

# Check if MCP server is enabled
is_mcp_server_enabled() {
  local server_name="${1:-}"
  local project="${2:-}"
  
  # Check if server exists
  if ! get_mcp_server_metadata "$server_name" >/dev/null 2>&1; then
    return 1
  fi
  
  # TODO: Check actual configuration files
  # For now, return true if server exists and is not in disabled directory
  local registry=$(get_mcp_registry)
  [ ! -d "$registry/disabled/$server_name" ]
}

# Generate MCP configuration from registry
generate_mcp_config() {
  local output_file="${1:-$HOME/.mcp.json}"
  local project="${2:-}"
  
  local registry=$(get_mcp_registry)
  local config='{"mcpServers": {}}'
  
  # Process each enabled server
  while IFS= read -r server_entry; do
    local server_name=$(basename "$server_entry")
    local server_type=$(dirname "$server_entry")
    
    # Skip if disabled
    if [ -d "$registry/disabled/$server_name" ]; then
      continue
    fi
    
    # Get server manifest
    local manifest=$(get_mcp_server_metadata "$server_name" 2>/dev/null)
    if [ -z "$manifest" ]; then
      continue
    fi
    
    # Extract server configuration
    local command=$(echo "$manifest" | jq -r '.server.command // "node"')
    local args=$(echo "$manifest" | jq -c '.server.args // []')
    local env=$(echo "$manifest" | jq -c '.server.env // {}')
    
    # Build server entry
    local server_config=$(jq -n \
      --arg cmd "$command" \
      --argjson args "$args" \
      --argjson env "$env" \
      '{command: $cmd, args: $args, env: $env}')
    
    # Add to config
    config=$(echo "$config" | jq \
      --arg name "$server_name" \
      --argjson server "$server_config" \
      '.mcpServers[$name] = $server')
  done < <(list_mcp_servers)
  
  # Apply project-specific overrides if provided
  if [ -n "$project" ]; then
    local project_config_dir=$(get_mcp_project_config_dir "$project")
    if [ -f "$project_config_dir/config.json" ]; then
      # TODO: Implement configuration merging
      echo -e "${YELLOW}Note:${NC} Project-specific configs not yet implemented" >&2
    fi
  fi
  
  # Write the configuration
  echo "$config" | jq '.' > "$output_file"
  chmod 644 "$output_file"
  
  echo -e "${GREEN}✓${NC} Generated MCP configuration at $output_file"
}

# Cache MCP registry information
update_mcp_cache() {
  local cache_dir=$(get_mcp_cache_dir)
  local cache_file="$cache_dir/registry.json"
  
  mkdir -p "$cache_dir"
  
  # Build cache data
  local cache_data='{"version": "1.0.0", "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'", "servers": {}}'
  
  # Add each server to cache
  while IFS= read -r server_entry; do
    local server_name=$(basename "$server_entry")
    local metadata=$(get_mcp_server_metadata "$server_name" 2>/dev/null)
    
    if [ -n "$metadata" ]; then
      cache_data=$(echo "$cache_data" | jq \
        --arg name "$server_name" \
        --argjson meta "$metadata" \
        '.servers[$name] = $meta')
    fi
  done < <(list_mcp_servers)
  
  # Write cache file
  echo "$cache_data" | jq '.' > "$cache_file"
  chmod 644 "$cache_file"
  
  echo -e "${GREEN}✓${NC} Updated MCP cache"
}

# Check if cache is valid (not older than 5 minutes)
is_cache_valid() {
  local cache_file="$(get_mcp_cache_dir)/registry.json"
  
  if [ ! -f "$cache_file" ]; then
    return 1
  fi
  
  local cache_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo 0)))
  [ "$cache_age" -lt 300 ]  # 5 minutes
}

# Get cached MCP registry data
get_cached_registry() {
  local cache_file="$(get_mcp_cache_dir)/registry.json"
  
  if ! is_cache_valid; then
    update_mcp_cache
  fi
  
  if [ -f "$cache_file" ]; then
    cat "$cache_file"
  else
    echo '{}'
  fi
}

# Lock functions for atomic operations
acquire_mcp_lock() {
  local lock_file="${1:-/tmp/mcp.lock}"
  local timeout="${2:-10}"
  
  local count=0
  while [ -f "$lock_file" ] && [ $count -lt $timeout ]; do
    sleep 1
    ((count++))
  done
  
  if [ $count -eq $timeout ]; then
    echo -e "${RED}Error:${NC} Failed to acquire lock (timeout)" >&2
    return 1
  fi
  
  echo $$ > "$lock_file"
}

release_mcp_lock() {
  local lock_file="${1:-/tmp/mcp.lock}"
  rm -f "$lock_file"
}

# Print MCP server info in a nice format
print_mcp_server_info() {
  local server_name="${1:-}"
  local metadata=$(get_mcp_server_metadata "$server_name" 2>/dev/null)
  
  if [ -z "$metadata" ]; then
    return 1
  fi
  
  echo -e "${BLUE}Server:${NC} $server_name"
  echo -e "${BLUE}Version:${NC} $(echo "$metadata" | jq -r '.metadata.version // "unknown"')"
  echo -e "${BLUE}Description:${NC} $(echo "$metadata" | jq -r '.metadata.description // "No description"')"
  echo -e "${BLUE}Author:${NC} $(echo "$metadata" | jq -r '.metadata.author // "Unknown"')"
  echo -e "${BLUE}Command:${NC} $(echo "$metadata" | jq -r '.server.command // "node"')"
  
  local capabilities=$(echo "$metadata" | jq -r '.server.capabilities[]? // empty' 2>/dev/null)
  if [ -n "$capabilities" ]; then
    echo -e "${BLUE}Capabilities:${NC}"
    echo "$capabilities" | sed 's/^/  - /'
  fi
  
  local required_env=$(echo "$metadata" | jq -r '.server.requiredEnv[]? // empty' 2>/dev/null)
  if [ -n "$required_env" ]; then
    echo -e "${BLUE}Required Env:${NC}"
    echo "$required_env" | sed 's/^/  - /'
  fi
}

# Export functions for use in other scripts
export -f get_mcp_registry
export -f get_mcp_cache_dir
export -f get_mcp_project_config_dir
export -f check_mcp_registry
export -f create_mcp_directories
export -f validate_mcp_server
export -f list_mcp_servers
export -f get_mcp_server_metadata
export -f is_mcp_server_enabled
export -f generate_mcp_config
export -f update_mcp_cache
export -f is_cache_valid
export -f get_cached_registry
export -f acquire_mcp_lock
export -f release_mcp_lock
export -f print_mcp_server_info