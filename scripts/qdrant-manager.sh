#!/bin/bash

set -euo pipefail

# Qdrant manager script for Claudex containers
# This script handles downloading, installing, and managing Qdrant within containers

QDRANT_VERSION="v1.14.1"
QDRANT_DIR="$HOME/.qdrant"
QDRANT_BIN="$QDRANT_DIR/bin/qdrant"
QDRANT_DATA="$QDRANT_DIR/data"
QDRANT_PID="$QDRANT_DIR/qdrant.pid"
QDRANT_LOG="$QDRANT_DIR/qdrant.log"
QDRANT_PORT="${QDRANT_PORT:-6333}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions
error() {
  echo -e "${RED}Error:${NC} $1" >&2
  exit 1
}

success() {
  echo -e "${GREEN}✓${NC} $1"
}

info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

# Detect system architecture
detect_architecture() {
  local arch=$(uname -m)
  case "$arch" in
    x86_64)
      echo "x86_64"
      ;;
    aarch64|arm64)
      echo "aarch64"
      ;;
    *)
      error "Unsupported architecture: $arch"
      ;;
  esac
}

# Download Qdrant binary for the current architecture
download_qdrant() {
  local arch=$(detect_architecture)
  info "Detected architecture: $arch"
  
  # Create directories
  mkdir -p "$QDRANT_DIR/bin" "$QDRANT_DATA"
  
  # Construct download URL based on architecture
  local download_url
  case "$arch" in
    x86_64)
      download_url="https://github.com/qdrant/qdrant/releases/download/${QDRANT_VERSION}/qdrant-x86_64-unknown-linux-gnu.tar.gz"
      ;;
    aarch64)
      # For ARM64, use the musl version which is provided
      download_url="https://github.com/qdrant/qdrant/releases/download/${QDRANT_VERSION}/qdrant-aarch64-unknown-linux-musl.tar.gz"
      ;;
  esac
  
  info "Downloading Qdrant ${QDRANT_VERSION} for $arch..."
  info "URL: $download_url"
  
  # Download and extract
  local temp_file="/tmp/qdrant-${QDRANT_VERSION}-${arch}.tar.gz"
  if ! curl -L -f -o "$temp_file" "$download_url"; then
    error "Failed to download Qdrant from $download_url"
  fi
  
  # Check if file was downloaded successfully
  if [ ! -s "$temp_file" ]; then
    error "Downloaded file is empty or missing"
  fi
  
  info "Extracting Qdrant..."
  # Extract to a temporary directory first to handle different archive structures
  local temp_extract="/tmp/qdrant-extract-$$"
  mkdir -p "$temp_extract"
  
  if ! tar -xzf "$temp_file" -C "$temp_extract"; then
    rm -rf "$temp_extract"
    rm -f "$temp_file"
    error "Failed to extract Qdrant"
  fi
  
  # Find the qdrant binary and move it
  if [ -f "$temp_extract/qdrant" ]; then
    mv "$temp_extract/qdrant" "$QDRANT_BIN"
  elif [ -f "$temp_extract/bin/qdrant" ]; then
    mv "$temp_extract/bin/qdrant" "$QDRANT_BIN"
  else
    # Search for the binary
    local binary=$(find "$temp_extract" -name "qdrant" -type f | head -1)
    if [ -n "$binary" ]; then
      mv "$binary" "$QDRANT_BIN"
    else
      rm -rf "$temp_extract"
      rm -f "$temp_file"
      error "Could not find qdrant binary in archive"
    fi
  fi
  
  # Clean up
  rm -rf "$temp_extract"
  rm -f "$temp_file"
  
  # Make executable
  chmod +x "$QDRANT_BIN"
  
  success "Qdrant ${QDRANT_VERSION} installed successfully"
}

# Check if Qdrant is installed
is_installed() {
  [[ -f "$QDRANT_BIN" && -x "$QDRANT_BIN" ]]
}

# Check if Qdrant is running
is_running() {
  if [[ -f "$QDRANT_PID" ]]; then
    local pid=$(cat "$QDRANT_PID")
    if ps -p "$pid" > /dev/null 2>&1; then
      return 0
    else
      # PID file exists but process is not running
      rm -f "$QDRANT_PID"
    fi
  fi
  return 1
}

# Start Qdrant
start_qdrant() {
  if is_running; then
    warning "Qdrant is already running (PID: $(cat "$QDRANT_PID"))"
    return 0
  fi
  
  if ! is_installed; then
    info "Qdrant not found. Installing..."
    download_qdrant
  fi
  
  info "Starting Qdrant on port $QDRANT_PORT..."
  
  # Start Qdrant in background
  export QDRANT__SERVICE__HTTP_PORT="$QDRANT_PORT"
  export QDRANT__STORAGE__STORAGE_PATH="$QDRANT_DATA"
  
  nohup "$QDRANT_BIN" > "$QDRANT_LOG" 2>&1 &
  local pid=$!
  
  # Save PID
  echo "$pid" > "$QDRANT_PID"
  
  # Wait a moment and check if it started successfully
  sleep 2
  if is_running; then
    success "Qdrant started successfully (PID: $pid)"
    info "API endpoint: http://localhost:$QDRANT_PORT"
    info "Dashboard: http://localhost:$QDRANT_PORT/dashboard"
    info "Logs: $QDRANT_LOG"
  else
    error "Failed to start Qdrant. Check logs at: $QDRANT_LOG"
  fi
}

# Stop Qdrant
stop_qdrant() {
  if ! is_running; then
    info "Qdrant is not running"
    return 0
  fi
  
  local pid=$(cat "$QDRANT_PID")
  info "Stopping Qdrant (PID: $pid)..."
  
  # Try graceful shutdown first
  kill "$pid" 2>/dev/null || true
  
  # Wait for process to stop
  local count=0
  while ps -p "$pid" > /dev/null 2>&1 && [[ $count -lt 10 ]]; do
    sleep 1
    count=$((count + 1))
  done
  
  # Force kill if still running
  if ps -p "$pid" > /dev/null 2>&1; then
    warning "Forcefully terminating Qdrant..."
    kill -9 "$pid" 2>/dev/null || true
  fi
  
  rm -f "$QDRANT_PID"
  success "Qdrant stopped"
}

# Show Qdrant status
show_status() {
  echo -e "${GREEN}Qdrant Status${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  if is_installed; then
    echo -e "Installation: ${GREEN}✓ Installed${NC}"
    echo -e "Version: ${QDRANT_VERSION}"
    echo -e "Binary: $QDRANT_BIN"
  else
    echo -e "Installation: ${RED}✗ Not installed${NC}"
  fi
  
  if is_running; then
    local pid=$(cat "$QDRANT_PID")
    echo -e "Status: ${GREEN}● Running${NC} (PID: $pid)"
    echo -e "Port: $QDRANT_PORT"
    echo -e "API: http://localhost:$QDRANT_PORT"
    echo -e "Dashboard: http://localhost:$QDRANT_PORT/dashboard"
    
    # Try to get Qdrant health
    if command -v curl &> /dev/null; then
      local health=$(curl -s "http://localhost:$QDRANT_PORT/health" 2>/dev/null || echo "unavailable")
      echo -e "Health: $health"
    fi
  else
    echo -e "Status: ${RED}○ Not running${NC}"
  fi
  
  echo -e "Data directory: $QDRANT_DATA"
  echo -e "Log file: $QDRANT_LOG"
}

# Show Qdrant logs
show_logs() {
  local follow=false
  if [[ "${1:-}" == "--follow" || "${1:-}" == "-f" ]]; then
    follow=true
  fi
  
  if [[ ! -f "$QDRANT_LOG" ]]; then
    info "No log file found at: $QDRANT_LOG"
    return
  fi
  
  if [[ "$follow" == true ]]; then
    tail -f "$QDRANT_LOG"
  else
    cat "$QDRANT_LOG"
  fi
}

# Clean Qdrant data
clean_data() {
  if is_running; then
    error "Cannot clean data while Qdrant is running. Stop it first."
  fi
  
  read -rp "$(echo -e "${YELLOW}?${NC} Delete all Qdrant data? This cannot be undone. [y/N] ")" confirm
  case "$confirm" in
    [yY][eE][sS]|[yY])
      rm -rf "$QDRANT_DATA"
      mkdir -p "$QDRANT_DATA"
      success "Qdrant data cleaned"
      ;;
    *)
      info "Operation cancelled"
      ;;
  esac
}

# Show help
show_help() {
  cat << EOF
Qdrant Manager - Manage Qdrant vector database in Claudex containers

Usage:
  qdrant-manager <command> [options]

Commands:
  start         Start Qdrant server
  stop          Stop Qdrant server
  restart       Restart Qdrant server
  status        Show Qdrant status
  logs          Show Qdrant logs
  logs -f       Follow Qdrant logs (live)
  install       Download and install Qdrant binary
  clean         Delete all Qdrant data (requires confirmation)
  help          Show this help message

Environment Variables:
  QDRANT_PORT   Port to run Qdrant on (default: 6333)

Examples:
  qdrant-manager start              # Start Qdrant on default port
  QDRANT_PORT=6334 qdrant-manager start  # Start on custom port
  qdrant-manager status             # Check if Qdrant is running
  qdrant-manager logs -f            # Follow live logs

EOF
}

# Main command dispatcher
main() {
  local command="${1:-help}"
  shift || true
  
  case "$command" in
    start)
      start_qdrant
      ;;
    stop)
      stop_qdrant
      ;;
    restart)
      stop_qdrant
      start_qdrant
      ;;
    status)
      show_status
      ;;
    logs)
      show_logs "$@"
      ;;
    install)
      if is_installed; then
        info "Qdrant is already installed"
      else
        download_qdrant
      fi
      ;;
    clean)
      clean_data
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      error "Unknown command: $command. Use 'qdrant-manager help' for usage."
      ;;
  esac
}

main "$@"