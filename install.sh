#!/bin/bash
# Installs the packages each dotfiles package needs, then stows the configs
# into $HOME. Arch/CachyOS only (uses pacman).
#
# Usage:
#   ./install.sh                  # install + stow everything
#   ./install.sh tmux nvim        # install + stow only the named packages
#   ./install.sh cli-tools        # install-only tools with no config to stow
#                                  # (uv, ruff, ty, node, bun, lazygit, just, yay)
#   ./install.sh --audit          # list explicitly-installed packages this
#                                  # script doesn't know about (audit only,
#                                  # installs/changes nothing)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${HOME}/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# Stow package name -> space-separated pacman package names it depends on.
declare -A DEPS=(
    [zsh]="zsh cachyos-zsh-config"
    [git]="git"
    [nvim]="neovim ripgrep fd base-devel unzip"
    [ghostty]="ghostty ttf-jetbrains-mono-nerd"
    [hypr]="hyprland xdg-desktop-portal-hyprland noctalia hyprpicker dolphin firefox gnome-text-editor gnome-calculator satty pavucontrol networkmanager qt6ct nwg-look"
    [btop]="btop"
    [tmux]="tmux"
    [ssh]="openssh"
    [scripts]="rsync tailscale"
    [cli-tools]="uv ruff nodejs npm lazygit just git base-devel"
)

# cli-tools has no ~/.config directory of its own to stow - it's just a
# grab-bag of CLI tools. Most come from pacman (see DEPS above), but bun and
# ty are installed via their own official installer scripts instead, to
# match how they're actually managed on this machine (not pacman-owned).
ALL_PACKAGES=(zsh git nvim ghostty hypr btop tmux ssh scripts cli-tools)

log() { printf '==> %s\n' "$1"; }

[[ -f /etc/arch-release ]] || { echo "error: this script targets Arch/CachyOS (pacman) only" >&2; exit 1; }
command -v pacman >/dev/null || { echo "error: pacman not found" >&2; exit 1; }

if [[ "${1:-}" == "--audit" ]]; then
    # yay is explicitly-installed and foreign once built, but it's handled
    # by install_yay rather than DEPS, so treat it as already-declared here.
    declared="$( { printf '%s\n' "${DEPS[@]}"; echo yay; } | tr ' ' '\n' | sort -u)"
    installed="$(pacman -Qqe | sort -u)"
    comm -23 <(printf '%s\n' "$installed") <(printf '%s\n' "$declared")
    exit 0
fi

targets=("$@")
[[ ${#targets[@]} -eq 0 ]] && targets=("${ALL_PACKAGES[@]}")

for pkg in "${targets[@]}"; do
    [[ -n "${DEPS[$pkg]+x}" ]] || { echo "error: unknown package '$pkg' (known: ${ALL_PACKAGES[*]})" >&2; exit 1; }
done

# Install stow plus every dependency for the requested packages in one
# transaction so pacman only prompts once.
to_install=(stow)
for pkg in "${targets[@]}"; do
    read -ra pkg_deps <<< "${DEPS[$pkg]}"
    to_install+=("${pkg_deps[@]}")
done

log "Installing packages: ${to_install[*]}"
sudo pacman -S --needed "${to_install[@]}"

# bun and ty aren't packaged the way we use them here - install (or skip if
# already present) via their own official installer scripts.
install_bun() {
    if command -v bun >/dev/null || [[ -x "${HOME}/.bun/bin/bun" ]]; then
        log "bun already installed, skipping"
        return
    fi
    log "Installing bun via official installer (bun.sh/install)"
    curl -fsSL https://bun.sh/install | bash
}

install_ty() {
    if command -v ty >/dev/null || [[ -x "${HOME}/.local/bin/ty" ]]; then
        log "ty already installed, skipping"
        return
    fi
    log "Installing ty via official installer (astral.sh/ty/install.sh)"
    curl -LsSf https://astral.sh/ty/install.sh | sh
}

# yay isn't in the official repos - build it from the AUR in a throwaway
# temp dir (git and base-devel are pulled in via cli-tools' pacman deps
# above). The clone is discarded once makepkg has installed the package.
install_yay() {
    if command -v yay >/dev/null; then
        log "yay already installed, skipping"
        return
    fi
    log "Installing yay from AUR"
    local build_dir
    build_dir="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "${build_dir}/yay"
    (cd "${build_dir}/yay" && makepkg -si)
    rm -rf "$build_dir"
}

for pkg in "${targets[@]}"; do
    if [[ "$pkg" == "cli-tools" ]]; then
        install_bun
        install_ty
        install_yay
    fi
done

# Move any real (non-symlink) file out of the way of a package's files
# before stowing, so stow never fails on a conflict.
backup_conflicts() {
    local pkg="$1" src rel dest
    while IFS= read -r -d '' src; do
        rel="${src#"$REPO_DIR"/"$pkg"/}"
        dest="${HOME}/${rel}"
        if [[ -e "$dest" && ! -L "$dest" ]]; then
            log "Backing up ~/${rel} -> ${BACKUP_DIR}/${rel}"
            mkdir -p "$(dirname "${BACKUP_DIR}/${rel}")"
            mv "$dest" "${BACKUP_DIR}/${rel}"
        fi
    done < <(find "${REPO_DIR}/${pkg}" -type f -print0)
}

cd "$REPO_DIR"
for pkg in "${targets[@]}"; do
    if [[ ! -d "${REPO_DIR}/${pkg}" ]]; then
        log "$pkg has no config directory, skipping stow"
        continue
    fi
    backup_conflicts "$pkg"
    log "Stowing $pkg"
    stow --restow "$pkg"
done

# scripts ships user systemd units alongside its ~/.local/bin executables -
# enable/refresh them now that they're stowed.
if [[ " ${targets[*]} " == *" scripts "* ]]; then
    log "Enabling wallsync.timer"
    systemctl --user daemon-reload
    systemctl --user enable --now wallsync.timer
fi

[[ -d "$BACKUP_DIR" ]] && log "Backed up pre-existing files to $BACKUP_DIR"
log "Done."
