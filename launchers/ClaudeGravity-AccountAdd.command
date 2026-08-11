#!/bin/zsh

export PATH="$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

clear
printf "ClaudeGravity - Привязка аккаунта\n\n"

if command -v acc >/dev/null 2>&1; then
  printf "Запускаю привязку Google/Antigravity аккаунта...\n\n"
  acc accounts add
else
  printf "Ошибка: утилита 'acc' (antigravity-claude-proxy) не найдена.\n"
  printf "Установите её командой: npm install -g antigravity-claude-proxy\n\n"
  printf "Нажмите любую клавишу..."
  read -k 1
  exit 1
fi

printf "\n--- Запуск ClaudeGravity ---\n"
read "reply?Хотите запустить ClaudeGravity прямо сейчас? [Y/n]: "
reply=${reply:-Y}

if [[ "$reply" =~ ^[Yy]$ ]]; then
  printf "\nНапоминание для Claude Desktop:\n"
  printf " 1. Меню Help -> Troubleshooting -> Enable Developer Mode\n"
  printf " 2. Переключите режим с 'Cowork' на 'Code'\n"
  printf " 3. Выберите модель: gemini-3.6-flash-high (Antigravity) 1M\n\n"
  exec "$(dirname "$0")/ClaudeGravity.command"
fi
