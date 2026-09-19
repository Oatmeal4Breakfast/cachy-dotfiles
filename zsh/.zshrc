# No oh-my-zsh, no powerlevel10k, no cachyos-config — prompt is starship only.
# (cachyos-config.zsh pulls in oh-my-zsh + p10k, which is what was mixing the
# russell/p10k look in with starship. Don't source it.)

# --- history ---
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS
export HISTCONTROL=ignoreboth
export HISTORY_IGNORE="(&|[bf]g|c|clear|history|exit|q|pwd|* --help)"

# --- behaviour ---
unsetopt CORRECT_ALL CORRECT          # no command auto-correction
setopt NO_BEEP AUTO_CD
export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"

# --- completion ---
autoload -Uz compinit && compinit -C
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# --- plugins (system packages, sourced directly, no omz) ---
[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[[ -f /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ]] && \
  source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

# arrow-key history search (requires history-substring-search above)
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# fzf keybindings + completion (Ctrl-R / Ctrl-T / Alt-C)
[[ -f /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
[[ -f /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh

# "command not found" handler
[[ -f /usr/share/doc/pkgfile/command-not-found.zsh ]] && \
  source /usr/share/doc/pkgfile/command-not-found.zsh

# --- man page colors ---
export LESS_TERMCAP_md="$(tput bold 2> /dev/null; tput setaf 2 2> /dev/null)"
export LESS_TERMCAP_me="$(tput sgr0 2> /dev/null)"

# --- aliases (kept from cachyos-config, minus the Arch-help ones you don't need to keep) ---
alias make="make -j`nproc`"
alias ninja="ninja -j`nproc`"
alias n="ninja"
alias rmpkg="sudo pacman -Rsn"
alias cleanch="sudo pacman -Scc"
alias fixpacman="sudo rm /var/lib/pacman/db.lck"
alias update="sudo pacman -Syu"
alias apt="man pacman"
alias apt-get="man pacman"
alias please="sudo"
alias tb="nc termbin.com 9999"
alias cleanup="sudo pacman -Rsn $(pacman -Qtdq)"
alias jctl="journalctl -p 3 -xb"
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"
alias ls="eza"
alias cat="bat"

export PATH="$HOME/.local/bin:$PATH"

. "$HOME/.local/share/../bin/env"

# bun completions
[ -s "/home/thoughts/.bun/_bun" ] && source "/home/thoughts/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# opencode
export PATH=/home/thoughts/.opencode/bin:$PATH

# text-editor
export EDITOR="nvim"
export VISUAL="nvim"

# aliases
alias lg="lazygit"

# --- prompt: starship only, must stay last ---
eval "$(starship init zsh)"
