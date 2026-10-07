#!/bin/bash
# Backup VS Code extensions
code-oss --list-extensions 2>/dev/null > packages/vscode-extensions.txt || code --list-extensions 2>/dev/null > packages/vscode-extensions.txt

# Backup NPM global packages (without versions for clean install)
npm list -g --depth=0 | grep '├──' | awk '{print $2}' | awk -F'@' '{if ($1 == "") print "@"$2; else print $1}' > packages/npm-global.txt
