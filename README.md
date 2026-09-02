# dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level
directory is a stow package whose contents mirror `$HOME`.

## Layout

- `zsh/` — `.zshrc` (CachyOS zsh config + powerlevel10k)
- `git/` — `.gitconfig`
- `nvim/` — `.config/nvim` (LazyVim)
- `ghostty/` — `.config/ghostty` (terminal)
- `hypr/` — `.config/hypr` (Hyprland WM)
- `btop/` — `.config/btop`
- `tmux/` — `.config/tmux` (terminal multiplexer)

`install.sh` also installs a `cli-tools` group with no config to stow:
`uv`, `ruff`, `node`, `npm`, `lazygit`, `just` via pacman, plus `bun` and
`ty` via their own official installer scripts (not pacman-packaged the way
they're used here).

## Usage

On a fresh Arch/CachyOS machine, `install.sh` installs each package's
dependencies via pacman and stows the configs, backing up any pre-existing
real file it would otherwise conflict with to `~/.dotfiles-backup/<timestamp>/`:

```sh
cd ~/dotfiles
./install.sh              # install + stow everything
./install.sh tmux nvim    # install + stow only the named packages
```

Manual stow usage still works if you'd rather manage packages yourself:

```sh
cd ~/dotfiles
stow zsh git nvim ghostty hypr btop tmux   # symlink packages into $HOME
stow -D zsh                           # remove a package's symlinks
```

To add a new package, create a directory here that mirrors the path under
`$HOME` (e.g. `kitty/.config/kitty/kitty.conf`), add its pacman deps to the
`DEPS` map and `ALL_PACKAGES` list in `install.sh`, then `stow <name>`.
