#!/usr/bin/env bash
set -euo pipefail

REPO="$HOME/repos/end4-dotfiles"

# origen (relativo a $HOME) -> destino (relativo a $REPO)
PAIRS=(
    ".config/hypr:config/hypr"
    ".config/illogical-impulse:config/illogical-impulse"
    ".config/quickshell:config/quickshell"
    ".config/fastfetch:config/fastfetch"
    ".config/cava:config/cava"
    ".local/bin:local/bin"
    ".local/share/applications:local/share/applications"
    ".config/autostart:config/autostart"
    ".config/systemd/user:config/systemd/user"
)

FILES=(
    ".config/mimeapps.list:config/mimeapps.list"
    ".config/kdedrc:config/kdedrc"
    ".inputrc:inputrc"
)

echo ":: sincronizando ~/ -> repo"

for pair in "${PAIRS[@]}"; do
    src="$HOME/${pair%%:*}"
    dst="$REPO/${pair##*:}"

    [ -d "$src" ] || { echo "  --  ${pair%%:*} (no existe)"; continue; }

    mkdir -p "$dst"
    rsync -a --delete \
        --exclude='*.before-*' \
        --exclude='*.antes-*' \
        --exclude='*.backup' \
        --exclude='*.backup-*' \
        --exclude='*.bak' \
        --exclude='*.old' \
        --exclude='*.tmp' \
        --exclude='*.save' \
        --exclude='*.save.*' \
        --exclude='*~' \
        --exclude='.git/' \
        --exclude='__pycache__/' \
        "$src/" "$dst/"

    echo "  ok  ${pair%%:*} -> ${pair##*:}"
done

for pair in "${FILES[@]}"; do
    src="$HOME/${pair%%:*}"
    dst="$REPO/${pair##*:}"
    [ -f "$src" ] || { echo "  --  ${pair%%:*} (no existe)"; continue; }
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
    echo "  ok  ${pair%%:*}"
done

echo ":: exportando lista de paquetes"
pacman -Qqe > "$REPO/packages-explicit.txt"
pacman -Qqem > "$REPO/packages-aur.txt"
echo "  ok  packages-explicit.txt / packages-aur.txt"

cd "$REPO"
echo ":: cambios pendientes"
git status --short
