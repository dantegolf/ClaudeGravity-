#!/bin/zsh

export PATH="$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

clear
printf "ClaudeGravity limits\n\n"

if command -v jq >/dev/null 2>&1; then
  curl -s http://127.0.0.1:8080/health | jq
else
  curl -s http://127.0.0.1:8080/health
fi

printf "\nНажмите любую клавишу..."
read -k 1
