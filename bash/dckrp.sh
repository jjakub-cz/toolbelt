#!/bin/bash

# -----------------------------------------------------------------------------
# dckrp.sh – Simple Docker Compose helper CLI
#
# Part of the 'toolbelt' project: https://github.com/jjakub-cz/toolbelt.git
# Author: Jakub Jakeš
# License: MIT
#
# This script provides a lightweight wrapper around common Docker Compose 
# commands. Intended for development environments, it simplifies routine 
# operations such as starting, stopping, cleaning up, and viewing logs.
# -----------------------------------------------------------------------------

# Colors
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m' # Reset

# Helper: done message
done_msg() {
  echo -e "${GREEN}...done${NC}\n"
}

case "$1" in
  help|--help|-h)
    echo -e "${YELLOW}dckrp: Available commands:${NC}"
    echo -e "  ${GREEN}dckrp ls${NC}                 – list all Docker containers"
    echo -e "  ${GREEN}dckrp images [--clean]${NC}   – show image stats, optionally clean only dangling images"
    echo -e "  ${GREEN}dckrp up${NC}                 – build & start Docker Compose project in current directory"
    echo -e "  ${GREEN}dckrp down${NC}               – stop and remove containers"
    echo -e "  ${GREEN}dckrp logs <name>${NC}        – follow logs of the specified container"
    echo -e "  ${GREEN}dckrp exec <name> [cmd]${NC}  – execute command (default: /bin/bash) inside container"
    echo -e "  ${GREEN}dckrp clean${NC}              – safe environment cleanup (without volumes)"
    echo -e "  ${GREEN}dckrp help${NC}               – show this help"
    echo ""
    ;;

  up)
    echo -e "${GREEN}Running docker compose up with \"-d --no-deps --build --force-recreate\"...${NC}"
    docker compose up -d --no-deps --build --force-recreate
    done_msg
    ;;
  
  down)
    echo -e "${RED}Stopping docker compose...${NC}"
    docker compose down
    done_msg
    ;;

  logs)
    if [ -z "$2" ]; then
      echo -e "${YELLOW}Please specify a container name: dckrp logs <name>${NC}\n"
    else
      echo -e "${GREEN}Streaming logs from container '$2'... (Ctrl+C to exit)${NC}"
      docker logs -f "$2"
      echo ""
    fi
    ;;

  clean)
    echo -e "${YELLOW}Cleaning up Docker environment...${NC}"
    docker compose down --remove-orphans
    docker container prune --force
    docker image prune --force
    docker network prune --force
    docker builder prune --force
    done_msg
    ;;
    
  exec)
    if [ -z "$2" ]; then
      echo -e "${YELLOW}Please specify a container name: dckrp exec <name> [command]${NC}\n"
    else
      container="$2"
      shift 2
      cmd="${*:-/bin/bash}"
      echo -e "${GREEN}Running '${cmd}' inside container '${container}'...${NC}"
      docker exec -ti "$container" $cmd
      echo ""
    fi
    ;;

  ls)
    echo -e "${GREEN}Listing all containers:${NC}"
    docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    ;;

  images)
    echo -e "${GREEN}📦 Docker Images Overview:${NC}"
    echo ""

    # Header
    printf "%-30s %-15s %-12s %-20s %-10s\n" "IMAGE" "SIZE" "IMAGE ID" "CREATED" "STATUS"
    printf "%-30s %-15s %-12s %-20s %-10s\n" "------------------------------" "---------------" "------------" "--------------------" "----------"

    docker images --format '{{.Repository}}:{{.Tag}}|{{.Size}}|{{.ID}}|{{.CreatedSince}}' \
    | while IFS='|' read -r name size id created; do
      if [[ "$name" == "<none>:<none>" ]]; then
        printf "${YELLOW}%-30s %-15s %-12s %-20s %-10s${NC}\n" "[DANGLING]" "$size" "$id" "$created" "dangling"
      else
        printf "%-30s %-15s %-12s %-20s %-10s\n" "$name" "$size" "$id" "$created" "ok"
      fi
    done | sort -k2 -h

    echo ""

    if [[ "$2" == "--clean" ]]; then
      echo -e "${RED}🗑️  Removing dangling images...${NC}"
      docker image prune --force
      done_msg
    else
      done_msg
    fi
    ;;

  *)
    echo -e "${RED}Unknown command: '$1'${NC}\n"
    echo -e "${YELLOW}Use '${GREEN}dckrp help${YELLOW}' to see available commands.${NC}\n"
    ;;
esac
