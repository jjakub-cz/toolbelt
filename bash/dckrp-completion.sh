#!/bin/bash

# -----------------------------------------------------------------------------
# dckrp-completion.sh – Simple Docker Compose helper CLI autocompletion.
#
# Part of the 'toolbelt' project: https://github.com/jjakub-cz/toolbelt.git
# Author: Jakub Jakeš
# License: MIT
#
# Autocompletion for dckrp command
# -----------------------------------------------------------------------------

_dckrp_completions() {
  local cur prev opts containers
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  opts="up down logs clean help ls exec"

  # If first argument, suggest subcommands
  if [[ $COMP_CWORD -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
    return 0
  fi

  # If logs or exec, suggest running containers
  if [[ "$prev" == "logs" || "$prev" == "exec" ]]; then
    containers=$(docker ps --format '{{.Names}}')
    COMPREPLY=( $(compgen -W "${containers}" -- "${cur}") )
    return 0
  fi
}

complete -F _dckrp_completions dckrp
