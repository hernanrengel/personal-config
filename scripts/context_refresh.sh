#!/usr/bin/env bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
cd "$HOME/scripts"
node check_calendar.mjs > "$HOME/.claude/context/calendar.txt" 2>/dev/null
