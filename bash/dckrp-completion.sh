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
  local cur prev words opts containers
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  opts="up down restart logs clean help ls exec images"

  # Main command completion
  if [[ $COMP_CWORD -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
    return 0
  fi

  # Completion for 'logs' and 'exec' → container names
  if [[ "$prev" == "logs" || "$prev" == "exec" ]]; then
    containers=$(docker ps --format '{{.Names}}')
    COMPREPLY=( $(compgen -W "${containers}" -- "${cur}") )
    return 0
  fi

  # Completion for 'images' → --clean
  if [[ "${COMP_WORDS[1]}" == "images" && $COMP_CWORD -eq 2 ]]; then
    COMPREPLY=( $(compgen -W "--clean" -- "${cur}") )
    return 0
  fi
}

complete -F _dckrp_completions dckrp

