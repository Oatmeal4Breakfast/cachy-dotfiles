# dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level
directory is a stow package whose contents mirror `$HOME`.

## Layout

- `zsh/` — `.zshrc` (CachyOS zsh config + powerlevel10k)
- `git/` — `.gitconfig`
- `nvim/` — `.config/nvim` (LazyVim)

## Usage

```sh
cd ~/dotfiles
stow zsh git nvim   # symlink a package into $HOME
stow -D zsh         # remove a package's symlinks
```

To add a new package, create a directory here that mirrors the path under
`$HOME` (e.g. `kitty/.config/kitty/kitty.conf`), then `stow <name>`.
