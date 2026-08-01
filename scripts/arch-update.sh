#!/bin/bash
set -Eeuo pipefail

# =========================
# OOM SAFETY LIMITS
# =========================
export MAKEFLAGS="-j2"
export NINJAFLAGS="-j2"
export CARGO_BUILD_JOBS=2
export MAX_JOBS=2

# =========================
# Logging
# =========================
LOG_DIR="$HOME/.logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/arch-update-$(date +%F_%H-%M-%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "🟢 Arch Linux — FULL SYSTEM UPDATE (PARALLEL SAFE)"
echo "🕒 $(date)"
echo "📄 Log file: $LOG_FILE"
echo "⚙️ Parallel jobs limited to 2"
echo "=========================================="

# =========================
# Pre-flight checks
# =========================
echo "🌐 Checking internet..."
if ! ping -c 2 archlinux.org >/dev/null; then
  echo "❌ No internet connection"
  exit 1
fi

echo "🔒 Checking pacman lock..."
if sudo fuser /var/lib/pacman/db.lck >/dev/null 2>&1; then
  echo "❌ Pacman is locked"
  exit 1
fi

# =========================
# Pacman update
# =========================
echo "📦 Updating system packages (pacman)..."
sudo pacman -Syu --noconfirm

# =========================
# AUR update function (parallel-safe)
# =========================
declare -a FAILED_PACKAGES=()

aur_update_package() {
  local helper=$1
  local pkg=$2
  local success=0

  for i in {1..3}; do
    echo "⬆️  Attempt $i/3 updating $pkg with $helper..."
    if "$helper" -S --noconfirm "$pkg"; then
      echo "✅ $pkg updated successfully"
      success=1
      break
    else
      echo "⚠️  $pkg failed on attempt $i"
      sleep 2
    fi
  done

  if [ $success -eq 0 ]; then
    echo "❌ $pkg failed to update after 3 attempts"
    FAILED_PACKAGES+=("$pkg")
  fi
}

aur_update_helper_parallel() {
  local helper=$1
  if ! command -v "$helper" >/dev/null; then
    echo "ℹ️ $helper not installed"
    return
  fi

  echo "🧩 Updating AUR packages with $helper (parallel-safe)..."
  packages=$("$helper" -Qm)  # List all AUR packages installed

  # Export la función y variables para xargs
  export -f aur_update_package
  export helper
  # export -f echo

  # Ejecuta 2 paquetes a la vez máximo
  echo "$packages" | xargs -P 2 -I {} bash -c 'aur_update_package "$helper" "{}"'
}

# =========================
# Update AUR
# =========================
aur_update_helper_parallel yay
aur_update_helper_parallel paru

# =========================
# Retry failed packages at the end (secuencial)
# =========================
if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
  echo "=========================================="
  echo "🔁 Retrying failed packages sequentially..."
  for pkg in "${FAILED_PACKAGES[@]}"; do
    echo "⬆️  Retrying $pkg..."
    aur_update_package yay "$pkg"
  done
fi

# =========================
# Summary
# =========================
echo "=========================================="
echo "✅ Update process completed"
if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
  echo "⚠️ Some packages still failed: ${FAILED_PACKAGES[*]}"
else
  echo "🎉 All packages updated successfully!"
fi
echo "=========================================="
