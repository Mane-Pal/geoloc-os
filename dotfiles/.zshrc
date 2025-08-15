if [[ -s ${ZDOTDIR:-${HOME}}/.zim/init.zsh ]]; then
  source ${ZDOTDIR:-${HOME}}/.zim/init.zsh
fi

alias ls='eza'
alias ll='eza -la'
alias cat='bat'
alias vim='nvim'

export PATH="$HOME/.local/bin:$PATH"

export EDITOR='nvim'
export VISUAL='nvim'

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
