#!/bin/bash
# Installs the packages each dotfiles package needs, then stows the configs
# into $HOME. Arch/CachyOS only (uses pacman).
#
# Usage:
#   ./install.sh                  # install + stow everything
#   ./install.sh tmux nvim        # install + stow only the named packages
#   ./install.sh cli-tools        # install-only tools with no config to stow
#                                  # (uv, ruff, ty, node, bun, lazygit, just, yay)
#   ./install.sh apps               # install-only desktop apps with no config to stow
#                                  # (discord, spotify-launcher via pacman;
#                                  #  notion-app-electron via yay/AUR)
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
    [cli-tools]="uv ruff nodejs npm lazygit just git base-devel go"
    [apps]="discord spotify-launcher"
)

# AUR package name -> space-separated AUR package names it depends on.
# Installed via yay after pacman deps and install_yay have run.
declare -A AUR_DEPS=(
    [apps]="notion-app-electron"
)

# cli-tools and apps have no ~/.config directory of their own to stow - they're
# just grab-bags of programs. Most come from pacman (see DEPS above), but bun and
# ty are installed via their own official installer scripts instead, to
# match how they're actually managed on this machine (not pacman-owned).
ALL_PACKAGES=(zsh git nvim ghostty hypr btop tmux ssh scripts cli-tools apps)

log() { printf '==> %s\n' "$1"; }

[[ -f /etc/arch-release ]] || { echo "error: this script targets Arch/CachyOS (pacman) only" >&2; exit 1; }
command -v pacman >/dev/null || { echo "error: pacman not found" >&2; exit 1; }

if [[ "${1:-}" == "--audit" ]]; then
    # yay is explicitly-installed and foreign once built, but it's handled
    # by install_yay rather than DEPS, so treat it as already-declared here.
    declared="$( { printf '%s\n' "${DEPS[@]}"; printf '%s\n' "${AUR_DEPS[@]}"; echo yay; } | tr ' ' '\n' | sort -u)"
    installed="$(pacman -Qqe | sort -u)"
    comm -23 <(printf '%s\n' "$installed") <(printf '%s\n' "$declared")
    exit 0
fi

targets=("$@")
[[ ${#targets[@]} -eq 0 ]] && targets=("${ALL_PACKAGES[@]}")

for pkg in "${targets[@]}"; do
    if [[ -z "${DEPS[$pkg]+x}" && -z "${AUR_DEPS[$pkg]+x}" ]]; then
        echo "error: unknown package '$pkg' (known: ${ALL_PACKAGES[*]})" >&2
        exit 1
    fi
done

# Install stow plus every dependency for the requested packages in one
# transaction so pacman only prompts once.
to_install=(stow)
for pkg in "${targets[@]}"; do
    [[ -n "${DEPS[$pkg]+x}" ]] || continue
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
    # Non-fatal on purpose: a yay build failure (no network, missing PGP
    # key, sudo prompt, ...) must not abort the stow step below under
    # `set -e`. --noconfirm keeps makepkg from stopping on its install
    # confirmation prompt.
    # NOTE: the clone forces HTTP/1.1 because aur.archlinux.org reliably
    # resets git's default HTTP/2 connection mid-handshake (SSL
    # "unexpected eof"), while HTTP/1.1 works fine.
    if git -c http.version=HTTP/1.1 clone https://aur.archlinux.org/yay.git "${build_dir}/yay" \
        && (cd "${build_dir}/yay" && makepkg -si --noconfirm); then
        log "yay installed"
    else
        log "WARNING: yay build failed, continuing without it (re-run './install.sh cli-tools' later to retry)"
    fi
    rm -rf "$build_dir"
}

# AUR packages are installed via yay once it's guaranteed present.
for pkg in "${targets[@]}"; do
    if [[ "$pkg" == "cli-tools" ]]; then
        install_bun
        install_ty
        install_yay
    elif [[ -n "${AUR_DEPS[$pkg]+x}" && -n "${AUR_DEPS[$pkg]}" ]]; then
        install_yay
    fi
done

install_aur_packages() {
    local aur_to_install=() pkg deps
    for pkg in "${targets[@]}"; do
        [[ -n "${AUR_DEPS[$pkg]+x}" ]] || continue
        [[ -n "${AUR_DEPS[$pkg]}" ]] || continue
        read -ra deps <<< "${AUR_DEPS[$pkg]}"
        aur_to_install+=("${deps[@]}")
    done
    [[ ${#aur_to_install[@]} -eq 0 ]] && return 0
    if ! command -v yay >/dev/null; then
        log "WARNING: yay not available, skipping AUR packages: ${aur_to_install[*]} (re-run './install.sh cli-tools' to retry the yay build, then this again)"
        return 0
    fi
    log "Installing AUR packages: ${aur_to_install[*]}"
    yay -S --needed "${aur_to_install[@]}"
}

install_aur_packages

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

# Make zsh the login shell when the zsh package was requested. CachyOS
# defaults to fish and nothing above changes the login shell, so without
# this the user keeps logging into fish even after a successful stow.
if [[ " ${targets[*]} " == *" zsh "* ]]; then
    zsh_path="$(command -v zsh)"
    current_shell="$(getent passwd "${USER:-$(id -un)}" | cut -d: -f7)"
    if [[ "$current_shell" == "$zsh_path" ]]; then
        log "zsh is already the login shell"
    elif chsh -s "$zsh_path"; then
        log "Login shell set to $zsh_path (takes effect on next login)"
    else
        log "WARNING: chsh failed (it usually needs an interactive password prompt); run 'chsh -s $zsh_path' yourself in a terminal"
    fi
fi

# scripts ships user systemd units alongside its ~/.local/bin executables -
# enable/refresh them now that they're stowed.
if [[ " ${targets[*]} " == *" scripts "* ]]; then
    log "Enabling wallsync.timer"
    systemctl --user daemon-reload
    systemctl --user enable --now wallsync.timer
fi

[[ -d "$BACKUP_DIR" ]] && log "Backed up pre-existing files to $BACKUP_DIR"
log "Done."
