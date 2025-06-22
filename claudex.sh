#!/bin/bash

set -euo pipefail

IMAGE_NAME="claudex-env"
CONTAINER_PREFIX="claudex_"

# Get the real path of the script, following symlinks
SCRIPT_PATH="$(realpath "$0" 2>/dev/null || readlink -f "$0" 2>/dev/null || echo "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

confirm() {
  read -rp "$(echo -e "${YELLOW}?${NC} $1 [y/N] ")" confirm
  case "$confirm" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

# Show detailed help
show_help() {
  cat << EOF
Claudex - Docker-based development environment manager

$(echo -e "${GREEN}Usage:${NC}")
  claudex <command> [options]

$(echo -e "${GREEN}Commands:${NC}")
  init                          First-time setup (builds image, creates symlink)
  start <project> [--dir PATH] [--port PORTS]
                                Start or attach to a project environment
                                (--dir required only for new projects)
                                (--port for port mappings, e.g. 8080,3000:3000)
  stop <project>                Stop a running container (keeps it for later)
  remove <project>              Remove a container (stopped or running)
  restart <project>             Restart an existing environment
  rebuild                       Rebuild the Docker image from scratch
  upgrade <project>             Upgrade container to latest image
  upgrade --all                 Upgrade all containers to latest image
  status [project]              Show environment status (all or specific)
  logs <project> [--follow]     View container logs (--follow for live logs)
  cleanup [--all | project]     Remove stopped containers
  qdrant <project> <action>     Manage Qdrant in a project (start/stop/status/logs)
  help                          Show this help message

$(echo -e "${GREEN}Examples:${NC}")
  claudex start myapp --dir ~/projects/myapp   # First time setup
  claudex start myapp --dir ~/projects/myapp --port 8080,3000:3000  # With ports
  claudex start myapp                          # Reattach to existing
  claudex upgrade myapp                        # Upgrade to latest image
  claudex upgrade --all                        # Upgrade all containers
  claudex status                               # List all environments
  claudex logs myapp --follow                  # View live logs
  claudex cleanup --all                        # Clean all stopped containers
  claudex qdrant myapp start                   # Start Qdrant in project
  claudex qdrant myapp status                  # Check Qdrant status

$(echo -e "${GREEN}Environment Details:${NC}")
  - Each project runs in a container named '${CONTAINER_PREFIX}<project>'
  - Project code is mounted at '/<project>' in the container
  - Environment data persists in '~/claudex/<project>' on the host
  - Containers include Claude Code and Codex pre-installed
  - Qdrant starts automatically on container entry (disable with CLAUDEX_AUTO_START_QDRANT=false)

EOF
}

# Get container name from project name
get_container_name() {
  echo "${CONTAINER_PREFIX}$1"
}

# Check if container exists
container_exists() {
  local container="$1"
  docker ps -a --filter "name=^/${container}$" --format "{{.Names}}" | grep -q "^${container}$"
}

# Check if container is running
container_running() {
  local container="$1"
  docker ps --filter "name=^/${container}$" --format "{{.Names}}" | grep -q "^${container}$"
}

# Format uptime for display
format_uptime() {
  local started="$1"
  
  # Handle empty or invalid input
  if [ -z "$started" ] || [ "$started" = "0001-01-01T00:00:00Z" ]; then
    echo "unknown"
    return
  fi
  
  # Convert Docker's ISO 8601 format to seconds since epoch
  # Docker format: 2025-06-05T15:46:29.315509752Z
  local cleaned_date="${started%%.*}"  # Remove fractional seconds
  cleaned_date="${cleaned_date/T/ }"   # Replace T with space
  cleaned_date="${cleaned_date%Z}"     # Remove Z suffix
  
  # Detect OS and use appropriate date parsing
  local start_ts
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS (BSD date)
    start_ts=$(date -j -u -f "%Y-%m-%d %H:%M:%S" "$cleaned_date" +%s 2>/dev/null || echo "0")
  else
    # Linux (GNU date)
    start_ts=$(date -u -d "$cleaned_date" +%s 2>/dev/null || echo "0")
  fi
  
  if [ "$start_ts" = "0" ]; then
    echo "unknown"
    return
  fi
  
  local now=$(date +%s)
  local diff=$((now - start_ts))
  
  if [ $diff -lt 60 ]; then
    echo "just now"
  elif [ $diff -lt 3600 ]; then
    echo "$((diff / 60)) minutes ago"
  elif [ $diff -lt 86400 ]; then
    echo "$((diff / 3600)) hours ago"
  else
    echo "$((diff / 86400)) days ago"
  fi
}

# Command: start
cmd_start() {
  local project=""
  local dir=""
  local ports=""
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir)
        shift
        dir="$1"
        ;;
      --port|-p)
        shift
        ports="$1"
        ;;
      *)
        if [ -z "$project" ]; then
          project="$1"
        else
          error "Unknown argument: $1"
        fi
        ;;
    esac
    shift
  done
  
  [ -z "$project" ] && error "Project name required. Usage: claudex start <project> [--dir PATH] [--port PORTS]"
  
  local container_name=$(get_container_name "$project")
  local claude_home="$HOME/claudex/$project"
  
  # Check if container already exists
  if container_exists "$container_name"; then
    if container_running "$container_name"; then
      info "Container '$container_name' is already running. Attaching..."
      docker exec -it "$container_name" bash
    else
      info "Container '$container_name' exists but is stopped. Restarting..."
      docker start "$container_name" >/dev/null
      docker exec -it "$container_name" bash
    fi
    return
  fi
  
  # New container - need directory
  [ -z "$dir" ] && error "Directory required for new project. Usage: claudex start $project --dir PATH [--port PORTS]"
  
  # Validate directory
  [ ! -d "$dir" ] && error "Directory '$dir' does not exist"
  
  local host_dir="$(realpath "$dir")"
  mkdir -p "$claude_home"
  
  # Assemble any -p flags for docker run
  local port_args=()
  if [ -n "$ports" ]; then
    IFS=',' read -r -a __port_list <<< "$ports"
    for __p in "${__port_list[@]}"; do
      # Trim whitespace
      __p=$(echo "$__p" | xargs)
      port_args+=( -p "$__p" )
    done
  fi
  
  info "Creating new container: $container_name"
  info "Source directory: $host_dir"
  info "Environment data: $claude_home"
  [ -z "$ports" ] || info "Port mappings: $ports"
  
  # Get host user's UID/GID for proper permissions
  local host_uid=$(id -u)
  local host_gid=$(id -g)
  
  docker run -it \
    ${port_args[@]+"${port_args[@]}"} \
    --name "$container_name" \
    --user "$host_uid:$host_gid" \
    -e HOME=/home/claudex \
    -e USER=claudex \
    -v "$host_dir":"/$project" \
    -v "$claude_home":"/home/claudex" \
    -v "$HOME/.ssh":"/home/claudex/.ssh:ro" \
    -v "$HOME/.gitconfig":"/home/claudex/.gitconfig:ro" \
    -w "/$project" \
    "$IMAGE_NAME"
}

# Command: stop
cmd_stop() {
  [ $# -ne 1 ] && error "Usage: claudex stop <project>"
  
  local project="$1"
  local container_name=$(get_container_name "$project")
  
  if ! container_exists "$container_name"; then
    error "Container '$container_name' does not exist"
  fi
  
  if ! container_running "$container_name"; then
    info "Container '$container_name' is already stopped"
    return
  fi
  
  if confirm "Stop container '$container_name'?"; then
    docker stop "$container_name" >/dev/null
    success "Container '$container_name' stopped"
  else
    info "Operation cancelled"
  fi
}

# Command: restart
cmd_restart() {
  [ $# -ne 1 ] && error "Usage: claudex restart <project>"
  
  local project="$1"
  local container_name=$(get_container_name "$project")
  
  if ! container_exists "$container_name"; then
    error "Container '$container_name' does not exist"
  fi
  
  info "Restarting container '$container_name'..."
  docker restart "$container_name" >/dev/null
  success "Container restarted"
  
  # Attach to the restarted container
  docker exec -it "$container_name" bash
}

# Command: remove
cmd_remove() {
  [ $# -ne 1 ] && error "Usage: claudex remove <project>"
  
  local project="$1"
  local container_name=$(get_container_name "$project")
  
  if ! container_exists "$container_name"; then
    error "Container '$container_name' does not exist"
  fi
  
  local status=$(docker inspect -f '{{.State.Status}}' "$container_name")
  local status_msg=""
  
  case "$status" in
    running) status_msg=" (currently running)" ;;
    exited) status_msg=" (stopped)" ;;
    *) status_msg=" (status: $status)" ;;
  esac
  
  if confirm "Remove container '$container_name'$status_msg?"; then
    docker rm -f "$container_name" >/dev/null
    success "Container '$container_name' removed"
  else
    info "Operation cancelled"
  fi
}

# Command: status
cmd_status() {
  local project="${1:-}"
  
  if [ -n "$project" ]; then
    # Show specific project status
    local container_name=$(get_container_name "$project")
    
    if ! container_exists "$container_name"; then
      error "Container '$container_name' does not exist"
    fi
    
    local status=$(docker inspect -f '{{.State.Status}}' "$container_name")
    local started=$(docker inspect -f '{{.State.StartedAt}}' "$container_name")
    local src_path=$(docker inspect -f '{{ range .Mounts }}{{ if eq .Destination "/'"$project"'" }}{{ .Source }}{{ end }}{{ end }}' "$container_name")
    
    echo -e "\n${GREEN}Project:${NC} $project"
    echo -e "${GREEN}Container:${NC} $container_name"
    echo -e "${GREEN}Status:${NC} $status"
    echo -e "${GREEN}Source:${NC} $src_path"
    echo -e "${GREEN}Started:${NC} $(format_uptime "$started")"
    
    # Show published ports without touching the table
    local ports_info=$(docker port "$container_name" 2>/dev/null | paste -sd ',' - || echo "none")
    echo -e "${GREEN}Ports:${NC} $ports_info"
    echo
  else
    # Show all environments
    echo -e "\n${GREEN}Active Environments:${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "%-20s %-12s %-20s %s\n" "PROJECT" "STATUS" "LAST STARTED" "SOURCE PATH"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Find all claudex containers
    local containers=$(docker ps -a --filter "name=^${CONTAINER_PREFIX}" --format "{{.Names}}")
    
    if [ -z "$containers" ]; then
      echo -e "${YELLOW}No environments found.${NC} Use 'claudex start <project> --dir PATH' to create one."
    else
      for container in $containers; do
        local project="${container#$CONTAINER_PREFIX}"
        local status=$(docker inspect -f '{{.State.Status}}' "$container")
        local started=$(docker inspect -f '{{.State.StartedAt}}' "$container")
        local src_path=$(docker inspect -f '{{ range .Mounts }}{{ if eq .Destination "/'"$project"'" }}{{ .Source }}{{ end }}{{ end }}' "$container" 2>/dev/null || echo "unknown")
        
        # Color code status
        case "$status" in
          running) status_colored="${GREEN}running${NC}" ;;
          exited) status_colored="${RED}stopped${NC}" ;;
          *) status_colored="${YELLOW}$status${NC}" ;;
        esac
        
        printf "%-20s %-25b %-20s %s\n" \
          "$project" \
          "$status_colored" \
          "$(format_uptime "$started")" \
          "$src_path"
      done
    fi
    echo
  fi
}

# Command: logs
cmd_logs() {
  local project=""
  local follow=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --follow|-f)
        follow=true
        ;;
      *)
        if [ -z "$project" ]; then
          project="$1"
        else
          error "Unknown argument: $1"
        fi
        ;;
    esac
    shift
  done
  
  [ -z "$project" ] && error "Project name required. Usage: claudex logs <project> [--follow]"
  
  local container_name=$(get_container_name "$project")
  
  if ! container_exists "$container_name"; then
    error "Container '$container_name' does not exist"
  fi
  
  if [ "$follow" = true ]; then
    docker logs -f "$container_name"
  else
    docker logs "$container_name"
  fi
}

# Command: cleanup
cmd_cleanup() {
  local target="${1:-}"
  
  if [ "$target" = "--all" ] || [ "$target" = "-a" ]; then
    # Clean all stopped containers
    local containers=$(docker ps -a --filter "name=^${CONTAINER_PREFIX}" --filter "status=exited" --format "{{.Names}}")
    
    if [ -z "$containers" ]; then
      info "No stopped containers to clean up"
      return
    fi
    
    echo -e "${YELLOW}Found stopped containers:${NC}"
    for container in $containers; do
      echo "  - $container"
    done
    
    if confirm "Remove ALL listed containers?"; then
      echo "$containers" | xargs -r docker rm >/dev/null
      success "Cleanup complete"
    else
      info "Cleanup cancelled"
    fi
  elif [ -n "$target" ]; then
    # Clean specific container
    local container_name=$(get_container_name "$target")
    
    if ! container_exists "$container_name"; then
      error "Container '$container_name' does not exist"
    fi
    
    local status=$(docker inspect -f '{{.State.Status}}' "$container_name")
    if [ "$status" != "exited" ]; then
      error "Container '$container_name' is not stopped (status: $status)"
    fi
    
    if confirm "Remove stopped container '$container_name'?"; then
      docker rm "$container_name" >/dev/null
      success "Container '$container_name' removed"
    else
      info "Cleanup cancelled"
    fi
  else
    error "Usage: claudex cleanup [--all | <project>]"
  fi
}

# Command: init
cmd_init() {
  echo -e "${GREEN}Welcome to Claudex!${NC}"
  echo "Setting up your development environment manager..."
  echo
  
  # Check Docker is installed
  if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Please install Docker first: https://docs.docker.com/get-docker/"
  fi
  
  # Check if Docker daemon is running
  if ! docker info &> /dev/null; then
    error "Docker daemon is not running. Please start Docker and try again."
  fi
  
  info "Docker is installed and running ✓"
  
  # Check if image already exists
  if docker images -q "$IMAGE_NAME" &> /dev/null && [ -n "$(docker images -q "$IMAGE_NAME" 2>/dev/null)" ]; then
    info "Docker image '$IMAGE_NAME' already exists"
    if confirm "Rebuild the image anyway?"; then
      cmd_rebuild
    else
      info "Using existing image"
    fi
  else
    info "Building Docker image for the first time..."
    
    # Validate we can find the Dockerfile
    if [ ! -f "$SCRIPT_DIR/Dockerfile" ]; then
      error "Cannot find Dockerfile at $SCRIPT_DIR/Dockerfile"
    fi
    
    # Build with timestamp
    local timestamp=$(date +"%Y%m%d-%H%M%S")
    local versioned_tag="${IMAGE_NAME}:${timestamp}"
    
    if ! docker build -t "$versioned_tag" -f "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR"; then
      error "Docker build failed"
    fi
    
    # Tag as production
    docker tag "$versioned_tag" "$IMAGE_NAME"
    success "Docker image built successfully"
  fi
  
  # Offer to create symlink
  echo
  local symlink_created=false
  local target_locations=("/usr/local/bin/claudex" "/usr/local/bin/cx")
  
  for target in "${target_locations[@]}"; do
    local name=$(basename "$target")
    
    # Check if symlink already exists
    if [ -L "$target" ] && [ "$(readlink -f "$target" 2>/dev/null)" = "$SCRIPT_PATH" ]; then
      info "Symlink '$name' already exists at $target ✓"
      symlink_created=true
      continue
    fi
    
    # Check if file exists but is not our symlink
    if [ -e "$target" ]; then
      info "File already exists at $target (not a symlink to claudex)"
      continue
    fi
    
    # Offer to create symlink
    if confirm "Create system-wide command '$name' at $target?"; then
      if sudo ln -sf "$SCRIPT_PATH" "$target"; then
        success "Created symlink: $target → $SCRIPT_PATH"
        symlink_created=true
      else
        info "Failed to create symlink at $target (permission denied?)"
      fi
    fi
  done
  
  # Show next steps
  echo
  echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}✓ Claudex is ready to use!${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
  echo
  echo -e "${BLUE}Next steps:${NC}"
  
  if [ "$symlink_created" = true ]; then
    echo "1. Start a new project:"
    echo "   claudex start myproject --dir ~/path/to/project"
    echo
    echo "2. Or use the short command:"
    echo "   cx start myproject --dir ~/path/to/project"
  else
    echo "1. Add this directory to your PATH:"
    echo "   export PATH=\"$SCRIPT_DIR:\$PATH\""
    echo
    echo "2. Or run directly:"
    echo "   $SCRIPT_PATH start myproject --dir ~/path/to/project"
  fi
  
  echo
  echo "3. Get help anytime:"
  echo "   claudex help"
  echo
  echo -e "${GREEN}Happy coding! 🚀${NC}"
}

# Command: upgrade
cmd_upgrade() {
  local project=""
  local upgrade_all=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all|-a)
        upgrade_all=true
        ;;
      *)
        if [ -z "$project" ]; then
          project="$1"
        else
          error "Unknown argument: $1"
        fi
        ;;
    esac
    shift
  done
  
  # Validate arguments
  if [ "$upgrade_all" = true ] && [ -n "$project" ]; then
    error "Cannot specify both --all and a project name"
  fi
  
  if [ "$upgrade_all" = false ] && [ -z "$project" ]; then
    error "Usage: claudex upgrade <project> OR claudex upgrade --all"
  fi
  
  # Function to upgrade a single container
  upgrade_container() {
    local proj="$1"
    local container_name=$(get_container_name "$proj")
    
    if ! container_exists "$container_name"; then
      error "Container '$container_name' does not exist"
    fi
    
    # Get container configuration before removal
    local src_path=$(docker inspect -f '{{ range .Mounts }}{{ if eq .Destination "/'"$proj"'" }}{{ .Source }}{{ end }}{{ end }}' "$container_name")
    local claude_home=$(docker inspect -f '{{ range .Mounts }}{{ if eq .Destination "/home/claudex" }}{{ .Source }}{{ end }}{{ end }}' "$container_name")
    
    # Validate mount paths
    if [ -z "$src_path" ] || [ -z "$claude_home" ]; then
      error "Failed to extract mount configuration from container '$container_name'"
    fi
    
    # Check if container is currently running
    local was_running=false
    if container_running "$container_name"; then
      was_running=true
    fi
    
    info "Upgrading container: $container_name"
    info "Project directory: $src_path"
    
    if ! confirm "Upgrade container '$container_name' to latest image?"; then
      info "Upgrade cancelled for '$container_name'"
      return 1
    fi
    
    # Remove old container
    docker rm -f "$container_name" >/dev/null 2>&1
    
    # Get host user's UID/GID for proper permissions
    local host_uid=$(id -u)
    local host_gid=$(id -g)
    
    # Recreate container with same mounts (in stopped state)
    if ! docker create \
      --name "$container_name" \
      --user "$host_uid:$host_gid" \
      -e HOME=/home/claudex \
      -e USER=claudex \
      -v "$src_path":"/$proj" \
      -v "$claude_home":"/home/claudex" \
      -v "$HOME/.ssh":"/home/claudex/.ssh:ro" \
      -v "$HOME/.gitconfig":"/home/claudex/.gitconfig:ro" \
      -w "/$proj" \
      -it \
      "$IMAGE_NAME" >/dev/null 2>&1; then
      error "Failed to recreate container '$container_name' after upgrade"
    fi
    
    success "Container '$container_name' upgraded successfully"
    
    # If it was running, offer to start it
    if [ "$was_running" = true ]; then
      if confirm "Container was running. Start it now?"; then
        info "Starting upgraded container..."
        docker start -ai "$container_name"
      else
        info "Use 'claudex start $proj' to start the upgraded container"
      fi
    else
      info "Use 'claudex start $proj' to start the upgraded container"
    fi
    
    return 0
  }
  
  if [ "$upgrade_all" = true ]; then
    # Find all claudex containers
    local containers=$(docker ps -a --filter "name=^${CONTAINER_PREFIX}" --format "{{.Names}}")
    
    if [ -z "$containers" ]; then
      info "No containers found to upgrade"
      return
    fi
    
    local count=$(echo "$containers" | wc -w)
    local running_containers=()
    
    info "Found $count container(s) to upgrade"
    
    # First pass: upgrade all containers
    for container in $containers; do
      local proj="${container#$CONTAINER_PREFIX}"
      echo
      
      # Get container configuration before removal
      local src_path=$(docker inspect -f '{{ range .Mounts }}{{ if eq .Destination "/'"$proj"'" }}{{ .Source }}{{ end }}{{ end }}' "$container")
      local claude_home=$(docker inspect -f '{{ range .Mounts }}{{ if eq .Destination "/home/claudex" }}{{ .Source }}{{ end }}{{ end }}' "$container")
      
      # Skip if we can't extract mount configuration
      if [ -z "$src_path" ] || [ -z "$claude_home" ]; then
        error "Failed to extract mount configuration from container '$container' - skipping"
        continue
      fi
      
      # Check if running before upgrade
      if container_running "$container"; then
        running_containers+=("$proj")
      fi
      
      info "Upgrading container: $container"
      info "Project directory: $src_path"
      
      # Remove old container
      docker rm -f "$container" >/dev/null 2>&1
      
      # Get host user's UID/GID for proper permissions
      local host_uid=$(id -u)
      local host_gid=$(id -g)
      
      # Recreate container with same mounts (in stopped state)
      if docker create \
        --name "$container" \
        --user "$host_uid:$host_gid" \
        -e HOME=/home/claudex \
        -e USER=claudex \
        -v "$src_path":"/$proj" \
        -v "$claude_home":"/home/claudex" \
        -v "$HOME/.ssh":"/home/claudex/.ssh:ro" \
        -v "$HOME/.gitconfig":"/home/claudex/.gitconfig:ro" \
        -w "/$proj" \
        -it \
        "$IMAGE_NAME" >/dev/null 2>&1; then
        success "Container '$container' upgraded"
      else
        error "Failed to recreate container '$container' after upgrade"
      fi
    done
    
    echo
    success "All containers upgraded successfully"
    
    # Handle previously running containers
    if [ ${#running_containers[@]} -gt 0 ]; then
      echo
      echo -e "${YELLOW}The following containers were running:${NC}"
      for proj in "${running_containers[@]}"; do
        echo "  - $proj"
      done
      
      if confirm "Start all previously running containers?"; then
        for proj in "${running_containers[@]}"; do
          local container_name=$(get_container_name "$proj")
          info "Starting $proj..."
          docker start "$container_name" >/dev/null 2>&1
        done
        info "All previously running containers have been started"
      else
        info "Use 'claudex start <project>' to start containers individually"
      fi
    fi
  else
    upgrade_container "$project"
  fi
}

# Command: qdrant
cmd_qdrant() {
  [ $# -lt 2 ] && error "Usage: claudex qdrant <project> <action> [options]"
  
  local project="$1"
  local action="$2"
  shift 2
  
  local container_name=$(get_container_name "$project")
  
  # Check if container exists
  if ! container_exists "$container_name"; then
    error "Container '$container_name' does not exist. Use 'claudex start $project' first."
  fi
  
  # Check if container is running
  if ! container_running "$container_name"; then
    error "Container '$container_name' is not running. Use 'claudex start $project' first."
  fi
  
  # Execute qdrant-manager command inside the container
  case "$action" in
    start)
      info "Starting Qdrant in project '$project'..."
      docker exec -it "$container_name" qdrant-manager start "$@"
      ;;
    stop)
      info "Stopping Qdrant in project '$project'..."
      docker exec -it "$container_name" qdrant-manager stop "$@"
      ;;
    restart)
      info "Restarting Qdrant in project '$project'..."
      docker exec -it "$container_name" qdrant-manager restart "$@"
      ;;
    status)
      docker exec -it "$container_name" qdrant-manager status "$@"
      ;;
    logs)
      docker exec -it "$container_name" qdrant-manager logs "$@"
      ;;
    install)
      info "Installing Qdrant in project '$project'..."
      docker exec -it "$container_name" qdrant-manager install "$@"
      ;;
    clean)
      docker exec -it "$container_name" qdrant-manager clean "$@"
      ;;
    help|--help|-h)
      docker exec -it "$container_name" qdrant-manager help
      ;;
    *)
      error "Unknown qdrant action: $action. Valid actions: start, stop, restart, status, logs, install, clean, help"
      ;;
  esac
}

# Command: rebuild
cmd_rebuild() {
  local keep_versions=3
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --keep-versions|-k)
        shift
        keep_versions="$1"
        ;;
      *)
        error "Unknown argument: $1"
        ;;
    esac
    shift
  done
  
  # Validate we can find the Dockerfile
  if [ ! -f "$SCRIPT_DIR/Dockerfile" ]; then
    error "Cannot find Dockerfile at $SCRIPT_DIR/Dockerfile"
  fi
  
  info "Rebuilding Docker image in: $SCRIPT_DIR"
  
  # Generate timestamp tag
  local timestamp=$(date +"%Y%m%d-%H%M%S")
  local versioned_tag="${IMAGE_NAME}:${timestamp}"
  
  # Check if old image exists
  if docker images -q "$IMAGE_NAME" >/dev/null 2>&1; then
    info "Current image found, will rebuild with version tag: $timestamp"
  fi
  
  # Build with version tag
  info "Building new image: $versioned_tag"
  if ! docker build -t "$versioned_tag" -f "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR"; then
    error "Docker build failed"
  fi
  
  # Tag as latest (production)
  info "Tagging as production: $IMAGE_NAME"
  docker tag "$versioned_tag" "$IMAGE_NAME"
  
  success "Image rebuilt successfully"
  echo -e "${GREEN}Version:${NC} $versioned_tag"
  echo -e "${GREEN}Production tag:${NC} $IMAGE_NAME"
  
  # Clean up old versions if requested
  if [ "$keep_versions" -gt 0 ]; then
    info "Keeping last $keep_versions versions"
    
    # Get all claudex-env versions sorted by creation date
    local all_versions=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^${IMAGE_NAME}:" | grep -E ":[0-9]{8}-[0-9]{6}$" | sort -r)
    local count=0
    
    while IFS= read -r version; do
      count=$((count + 1))
      if [ $count -gt $keep_versions ]; then
        info "Removing old version: $version"
        docker rmi "$version" >/dev/null 2>&1 || true
      fi
    done <<< "$all_versions"
  fi
  
  # Show final image list
  echo
  echo -e "${GREEN}Available images:${NC}"
  docker images --format "table {{.Repository}}:{{.Tag}}\t{{.CreatedAt}}\t{{.Size}}" | grep "^${IMAGE_NAME}" || true
}

# Main command dispatcher
main() {
  [ $# -eq 0 ] && { show_help; exit 0; }
  
  local command="$1"
  shift
  
  case "$command" in
    init)
      cmd_init "$@"
      ;;
    start)
      cmd_start "$@"
      ;;
    stop)
      cmd_stop "$@"
      ;;
    remove)
      cmd_remove "$@"
      ;;
    restart)
      cmd_restart "$@"
      ;;
    rebuild)
      cmd_rebuild "$@"
      ;;
    status)
      cmd_status "$@"
      ;;
    logs)
      cmd_logs "$@"
      ;;
    cleanup)
      cmd_cleanup "$@"
      ;;
    upgrade)
      cmd_upgrade "$@"
      ;;
    qdrant)
      cmd_qdrant "$@"
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      error "Unknown command: $command. Use 'claudex help' for usage information."
      ;;
  esac
}

main "$@"