#!/bin/bash

_dckrp_completions() {
  local cur prev opts containers
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  opts="up down logs clean help ls"

  if [[ $COMP_CWORD -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
  elif [[ "$prev" == "logs" ]]; then
    containers=$(docker ps --format '{{.Names}}')
    COMPREPLY=( $(compgen -W "${containers}" -- ${cur}) )
  fi
}

complete -F _dckrp_completions dckrp
