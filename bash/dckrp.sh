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
    echo -e "  ${GREEN}dckrp ls${NC}            – list all Docker containers"
    echo -e "  ${GREEN}dckrp up${NC}            – build & start Docker Compose project in current directory"
    echo -e "  ${GREEN}dckrp down${NC}          – stop and remove containers"
    echo -e "  ${GREEN}dckrp logs <name>${NC}   – follow logs of the specified container"
    echo -e "  ${GREEN}dckrp clean${NC}         – safe environment cleanup (without volumes)"
    echo -e "  ${GREEN}dckrp help${NC}          – show this help"
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

  ls)
    echo -e "${GREEN}Listing all containers:${NC}"
    docker ps -a
    echo ""
    ;;

  *)
    echo -e "${RED}Unknown command: '$1'${NC}\n"
    echo -e "${YELLOW}Use '${GREEN}dckrp help${YELLOW}' to see available commands.${NC}\n"
    ;;
esac
