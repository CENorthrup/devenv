#!/usr/bin/env bash
set -euo pipefail
action=${1:-help}
prezto_revision=cff2d01871425b1b80710f8ec6a475c5a53145b4
lazy_revision=85c7ff3711b730b4030d03144f6db6375044ae82
fail() { printf '%s\n' "$*" >&2; exit 1; }
export PATH="$HOME/.local/bin:$PATH"
case "$action" in
  user-install)
    [[ $EUID != 0 ]] || fail 'Run as the normal user.'
    mkdir -p "$HOME/.config"
    if [[ ! -e $HOME/.config/prezto ]]; then
      git clone --no-checkout https://github.com/sorin-ionescu/prezto.git "$HOME/.config/prezto"
      git -C "$HOME/.config/prezto" checkout --detach "$prezto_revision"
      git -C "$HOME/.config/prezto" submodule update --init --recursive
    else
      [[ $(git -C "$HOME/.config/prezto" rev-parse HEAD) == "$prezto_revision" ]] || fail 'Existing Prezto version differs; review before upgrading.'
      git -C "$HOME/.config/prezto" submodule update --init --recursive
    fi
    ;;
  editor-install)
    [[ $EUID != 0 ]] || fail 'Run as the normal user.'
    lazy="$HOME/.local/share/nvim/lazy/lazy.nvim"
    editor_marker="$HOME/.local/state/devenv-shell/editor-installed"
    if [[ ! -e $lazy ]]; then
      git clone --filter=blob:none --no-checkout https://github.com/folke/lazy.nvim.git "$lazy"
      git -C "$lazy" checkout --detach "$lazy_revision"
    elif [[ $(git -C "$lazy" rev-parse HEAD) != "$lazy_revision" ]]; then
      fail 'Existing lazy.nvim version differs; review before upgrading.'
    fi
    lazyvim="$HOME/.local/share/nvim/lazy/LazyVim/lua/lazyvim/init.lua"
    snacks="$HOME/.local/share/nvim/lazy/snacks.nvim/lua/snacks/init.lua"
    if [[ ! -f $lazyvim || ! -f $snacks ]]; then
      rm -f -- "$editor_marker"
    fi
    if [[ ! -e $editor_marker ]]; then
      # The first pass installs LazyVim itself; the second can then load its
      # imported specifications and restore the complete locked plugin set.
      DEVENV_EDITOR_INSTALL=1 nvim --headless '+Lazy! restore' +qa || true
      DEVENV_EDITOR_INSTALL=1 nvim --headless '+Lazy! restore' +qa
      [[ -f $lazyvim && -f $snacks ]] || fail 'LazyVim plugin installation is incomplete.'
      mkdir -p "$(dirname "$editor_marker")"
      touch "$editor_marker"
    fi
    output=$(nvim --headless '+lua assert(vim.fn.exists(":Lazy") == 2)' +qa 2>&1) || {
      printf '%s\n' "$output" >&2
      fail 'Neovim startup check failed.'
    }
    [[ $output != *'Error detected'* && $output != *'not installed'* ]] || {
      printf '%s\n' "$output" >&2
      fail 'Neovim reported an incomplete plugin setup.'
    }
    ;;
  check)
    zsh -lic '
      for tool in git ssh chezmoi zsh starship eza bat fd rg fzf yazi nvim tmux; do
        command -v $tool || exit 1
      done
      [[ -n $ZPREZTODIR && -f $ZPREZTODIR/init.zsh ]] || exit 1
      typeset -a devenv_pmodules
      zstyle -a ":prezto:load" pmodule devenv_pmodules || exit 1
      (( ${devenv_pmodules[(I)autosuggestions]} )) || exit 1
      (( ${devenv_pmodules[(I)syntax-highlighting]} )) || exit 1
      [[ -n ${functions[_zsh_autosuggest_start]} ]] || exit 1
      [[ -n ${functions[_zsh_highlight]} ]] || exit 1
      [[ -n ${functions[_devenv_mode_title]} ]] || exit 1
      for name in vim cat gg gl dd ls lsa zshrc sozsh; do
        alias "$name" >/dev/null || exit 1
      done
      alias ls
      alias cat
      bindkey -M viins jk
    '
    nvim --headless -u NONE '+luafile ~/.config/nvim/lua/config/keymaps.lua' '+lua local mapping = vim.fn.maparg("jk", "i", false, true); assert(mapping.rhs == "<Esc>")' +qa
    output=$(nvim --headless '+lua assert(vim.fn.exists(":Lazy") == 2)' +qa 2>&1) || {
      printf '%s\n' "$output" >&2
      fail 'Neovim startup check failed.'
    }
    [[ $output != *'Error detected'* && $output != *'not installed'* ]] || {
      printf '%s\n' "$output" >&2
      fail 'Neovim reported an incomplete plugin setup.'
    }
    ;;
  *) echo 'Usage: bash wsl/shell-setup.sh {user-install|editor-install|check}' ;;
esac

