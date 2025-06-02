#!/bin/bash

set -euo pipefail

IMAGE_NAME="claudex-env"

usage() {
  echo "Usage:"
  echo "  claudex [projname] [dir]   # Start or reattach a container"
  echo "  claudex [projname]         # Reattach or restart an existing container"
  echo "  claudex stop [projname]    # Stop and remove a container"
  echo "  claudex list               # List running containers and known environments"
  echo "  claudex cleanup [projname|-a]  # Cleanup stopped containers with confirmation"
  exit 1
}

confirm() {
  read -rp "$1 [y/N] " confirm
  case "$confirm" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

if [ $# -eq 0 ]; then
  usage
fi

COMMAND="$1"

if [ "$COMMAND" = "list" ]; then
  echo "=== Running Containers ==="
  docker ps --filter "ancestor=$IMAGE_NAME" --format "{{.Names}}\t{{.Status}}"

  echo ""
  echo "=== Available Environments ==="
  for d in "$HOME"/.claude_*; do
    [ -d "$d" ] || continue
    name="${d##*/.claude_}"

    container_exists=$(docker ps -a --filter "name=^/${name}$" --format "{{.Names}}")

    src_path="(not created)"
    last_used="(never started)"

    if [ "$container_exists" = "$name" ]; then
      # Get source mount for /$name (e.g. /project-foo)
      src_path=$(docker inspect -f '{{ range .Mounts }}{{ if eq .Destination "/'"$name"'" }}{{ .Source }}{{ end }}{{ end }}' "$name" 2>/dev/null || echo "(unknown)")
      started=$(docker inspect -f '{{.State.StartedAt}}' "$name" 2>/dev/null || echo "")
      last_used=$(date -d "$started" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$started")
    fi

    printf "%-16s %-30s Last used: %-20s Src: %s\n" "$name" "$d" "$last_used" "$src_path"
  done

  exit 0
fi

if [ "$COMMAND" = "cleanup" ]; then
  if [ $# -ne 2 ]; then
    echo "Usage: claudex cleanup [projname|-a]"
    exit 1
  fi

  TARGET="$2"

  if [ "$TARGET" = "-a" ]; then
    CONTAINERS=$(docker ps -a --filter "ancestor=$IMAGE_NAME" --filter "status=exited" --format "{{.Names}}")
    if [ -z "$CONTAINERS" ]; then
      echo "No stopped claudex containers to clean up."
      exit 0
    fi

    echo "Found stopped containers:"
    echo "$CONTAINERS"
    if confirm "Remove ALL listed containers?"; then
      echo "$CONTAINERS" | xargs -r docker rm
      echo "Cleanup complete."
    else
      echo "Cleanup cancelled."
    fi

  else
    STATUS=$(docker inspect -f '{{.State.Status}}' "$TARGET" 2>/dev/null || true)
    if [ "$STATUS" != "exited" ]; then
      echo "Container '$TARGET' is not in a stopped state or doesn't exist."
      exit 1
    fi

    if confirm "Remove stopped container '$TARGET'?"; then
      docker rm "$TARGET"
      echo "'$TARGET' removed."
    else
      echo "Cleanup cancelled."
    fi
  fi

  exit 0
fi

if [ "$COMMAND" = "stop" ]; then
  if [ $# -ne 2 ]; then
    echo "Usage: claudex stop [projname]"
    exit 1
  fi
  docker rm -f "$2" && echo "Stopped and removed $2"
  exit 0
fi

# PROJECT container start or reattach logic
PROJ="$1"
CONTAINER_NAME="$PROJ"
CLAUDE_HOME="$HOME/.claude_$PROJ"

EXISTS=$(docker ps -a --filter "name=^/${CONTAINER_NAME}$" --format "{{.Names}}")

if [ "$#" -eq 1 ] && [ "$EXISTS" = "$CONTAINER_NAME" ]; then
  RUNNING=$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME")
  if [ "$RUNNING" = "true" ]; then
    echo "Reattaching to running container: $CONTAINER_NAME"
    docker exec -it "$CONTAINER_NAME" bash
  else
    echo "Restarting and attaching to container: $CONTAINER_NAME"
    docker start -ai "$CONTAINER_NAME"
  fi
  exit 0
fi

# New container start — requires both projname and dir
if [ "$#" -ne 2 ]; then
  echo "Error: Directory argument required to create new container."
  echo "Usage: claudex [projname] [dir]"
  exit 1
fi

HOST_DIR="$(realpath "$2")"
mkdir -p "$CLAUDE_HOME"

echo "Starting new container: $CONTAINER_NAME"
docker run -it \
  --name "$CONTAINER_NAME" \
  -v "$HOST_DIR":"/$PROJ" \
  -v "$CLAUDE_HOME":"/home/claudex/.claude" \
  -w "/$PROJ" \
  "$IMAGE_NAME"

