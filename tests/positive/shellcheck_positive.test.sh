#!/usr/bin/env bash

no_shellcheck=0
target_type=0
target=0
exit_code=0
if [[ -z "$no_shellcheck" ]]; then
  printf ">> shellcheck...\n";
  if [[ $target_type == "directory" ]]; then
    for f in "$target"/**/*.sh; do
       # if glob does not match, stop execution
       [[ -e "$f" ]] || continue
       shellcheck "$f" --shell=bash || exit_code=1
    done
  elif [[ "${target: -3}" == ".sh" ]]; then
    shellcheck "$target" || exit_code=1
  fi
fi
exit $exit_code