#!/usr/bin/env bash
#
# Restores this dotfiles repository into the current user's home directory.
#
#   ./install.sh              copy configuration only
#   ./install.sh --packages   also install packages from the exported lists
#   ./install.sh --dry-run    print what would happen, change nothing
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config/dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

INSTALL_PACKAGES=false
DRY_RUN=false

for arg in "$@"; do
    case "$arg" in
        --packages) INSTALL_PACKAGES=true ;;
        --dry-run)  DRY_RUN=true ;;
        -h|--help)
            sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 1
            ;;
    esac
done

# repository path -> path relative to $HOME
DIRS=(
    "config/hypr:.config/hypr"
    "config/illogical-impulse:.config/illogical-impulse"
    "config/quickshell:.config/quickshell"
    "config/fastfetch:.config/fastfetch"
    "config/cava:.config/cava"
    "config/autostart:.config/autostart"
    "config/systemd/user:.config/systemd/user"
    "local/bin:.local/bin"
    "local/share/applications:.local/share/applications"
)

FILES=(
    "config/mimeapps.list:.config/mimeapps.list"
    "config/kdedrc:.config/kdedrc"
    "inputrc:.inputrc"
)

log()  { printf '  %s\n' "$*"; }
step() { printf '\n:: %s\n' "$*"; }

run() {
    if [ "$DRY_RUN" = true ]; then
        printf '  [dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

# ---------------------------------------------------------------- sanity ----

step "Checking environment"

if [ ! -d "$REPO_DIR/config" ]; then
    echo "This script must run from inside the repository." >&2
    exit 1
fi

if ! command -v hyprctl >/dev/null 2>&1; then
    log "warning: hyprctl not found; Hyprland may not be installed yet"
fi

log "repository: $REPO_DIR"
log "target:     $HOME"
[ "$DRY_RUN" = true ] && log "mode:       dry run (nothing will be written)"

# -------------------------------------------------------------- packages ----

if [ "$INSTALL_PACKAGES" = true ]; then
    step "Installing packages"

    if ! command -v pacman >/dev/null 2>&1; then
        echo "pacman not found. Package installation only works on Arch-based systems." >&2
        exit 1
    fi

    if [ -f "$REPO_DIR/packages-explicit.txt" ]; then
        # Repository packages: everything explicit minus the AUR-only entries.
        mapfile -t aur_pkgs < <(cat "$REPO_DIR/packages-aur.txt" 2>/dev/null || true)
        repo_list="$(mktemp)"

        if [ ${#aur_pkgs[@]} -gt 0 ]; then
            grep -vxF -f "$REPO_DIR/packages-aur.txt" \
                "$REPO_DIR/packages-explicit.txt" > "$repo_list" || true
        else
            cp "$REPO_DIR/packages-explicit.txt" "$repo_list"
        fi

        log "repository packages: $(wc -l < "$repo_list")"
        run sudo pacman -S --needed --noconfirm - < "$repo_list" || \
            log "warning: some repository packages failed to install"
        rm -f "$repo_list"
    else
        log "packages-explicit.txt not found, skipping"
    fi

    if [ -f "$REPO_DIR/packages-aur.txt" ] && [ -s "$REPO_DIR/packages-aur.txt" ]; then
        if command -v yay >/dev/null 2>&1; then
            log "AUR packages: $(wc -l < "$REPO_DIR/packages-aur.txt")"
            run yay -S --needed --noconfirm - < "$REPO_DIR/packages-aur.txt" || \
                log "warning: some AUR packages failed to build"
        else
            log "yay not found; install an AUR helper and re-run to get AUR packages"
        fi
    fi
fi

# ---------------------------------------------------------------- backup ----

step "Backing up existing configuration"

needs_backup=false
for pair in "${DIRS[@]}" "${FILES[@]}"; do
    [ -e "$HOME/${pair##*:}" ] && needs_backup=true
done

if [ "$needs_backup" = true ]; then
    run mkdir -p "$BACKUP_DIR"

    for pair in "${DIRS[@]}" "${FILES[@]}"; do
        target="$HOME/${pair##*:}"
        [ -e "$target" ] || continue
        dest="$BACKUP_DIR/${pair##*:}"
        run mkdir -p "$(dirname "$dest")"
        run cp -a "$target" "$dest"
    done

    log "saved to $BACKUP_DIR"
else
    log "nothing to back up"
fi

# --------------------------------------------------------------- restore ----

step "Restoring configuration"

for pair in "${DIRS[@]}"; do
    src="$REPO_DIR/${pair%%:*}"
    dst="$HOME/${pair##*:}"

    if [ ! -d "$src" ]; then
        log "--  ${pair%%:*} (not in repository)"
        continue
    fi

    run mkdir -p "$dst"
    run cp -a "$src/." "$dst/"
    log "ok  ${pair##*:}"
done

for pair in "${FILES[@]}"; do
    src="$REPO_DIR/${pair%%:*}"
    dst="$HOME/${pair##*:}"

    if [ ! -f "$src" ]; then
        log "--  ${pair%%:*} (not in repository)"
        continue
    fi

    run mkdir -p "$(dirname "$dst")"
    run cp -a "$src" "$dst"
    log "ok  ${pair##*:}"
done

# ------------------------------------------------------------ executables ---

step "Fixing permissions"

if [ -d "$HOME/.local/bin" ]; then
    run find "$HOME/.local/bin" -maxdepth 1 -type f -exec chmod +x {} +
    log "ok  ~/.local/bin"
fi

for script in \
    "$HOME/.config/hypr/scripts/toggle-floating-mode.py" \
    "$HOME/.config/hypr/hyprland/scripts" \
    "$HOME/.config/hypr/custom/scripts"
do
    [ -e "$script" ] || continue
    if [ -d "$script" ]; then
        run find "$script" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} +
    else
        run chmod +x "$script"
    fi
done
log "ok  Hyprland scripts"

# ---------------------------------------------------------------- systemd ---

step "Applying systemd user units"

if command -v systemctl >/dev/null 2>&1; then
    run systemctl --user daemon-reload

    # swaync would otherwise claim org.freedesktop.Notifications before
    # quickshell does, which silently replaces the shell's notification popups.
    run systemctl --user mask swaync.service 2>/dev/null || true
    log "ok  swaync masked"

    # kded6 crashes repeatedly without a full Plasma installation.
    run systemctl --user mask plasma-kded6.service 2>/dev/null || true
    log "ok  plasma-kded6 masked"
else
    log "systemctl not found, skipping"
fi

# ------------------------------------------------------------ mime caches ---

step "Updating desktop databases"

if command -v update-desktop-database >/dev/null 2>&1; then
    run update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    log "ok  desktop database"
fi

# ---------------------------------------------------------------- reload ----

step "Reloading"

if command -v hyprctl >/dev/null 2>&1 && hyprctl instances >/dev/null 2>&1; then
    run hyprctl reload || true
    log "ok  Hyprland reloaded"
    log "run 'pkill -f \"qs -c\"' and let Hyprland restart quickshell to apply shell changes"
else
    log "log into Hyprland to apply the configuration"
fi

printf '\nDone.\n'
[ "$needs_backup" = true ] && printf 'Previous configuration: %s\n' "$BACKUP_DIR"
exit 0
