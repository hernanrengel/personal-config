#!/usr/bin/env bash

set -e

PKG="antigravity"

echo "🔍 Looking for an AUR helper..."

if command -v yay &>/dev/null; then
  AUR_HELPER="yay"
elif command -v paru &>/dev/null; then
  AUR_HELPER="paru"
else
  echo "❌ No AUR helper found (yay or paru)."
  echo "Please install one to continue."
  exit 1
fi

echo "✅ Using AUR helper: $AUR_HELPER"
echo "📦 Package: $PKG"
echo

echo "⬆️  Updating Antigravity from AUR..."
$AUR_HELPER -Syu --needed "$PKG"

echo
echo "🧠 Installed Antigravity version:"
antigravity --version | head -n 1

echo
echo "✨ Antigravity update completed (if a newer version was available)."
