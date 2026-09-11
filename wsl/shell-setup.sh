#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
chezmoi_config="$root/chezmoi.toml"
action=${1:-help}
prezto_revision=cff2d01871425b1b80710f8ec6a475c5a53145b4
lazy_revision=85c7ff3711b730b4030d03144f6db6375044ae82
packages=(zsh eza bat fd-find ripgrep fzf neovim starship tmux unzip)
fail() { printf '%s\n' "$*" >&2; exit 1; }
export PATH="$HOME/.local/bin:$PATH"
case "$action" in
  packages)
    . /etc/os-release
    [[ $ID == ubuntu && $VERSION_ID == 26.04 ]] || fail 'Tested package profile requires Ubuntu 26.04.'
    admin=(); [[ $EUID == 0 ]] || admin=(sudo)
    missing=()
    for p in "${packages[@]}"; do
      [[ $(dpkg-query -W -f='${Status}' "$p" 2>/dev/null || true) == 'install ok installed' ]] || missing+=("$p")
    done
    if ((${#missing[@]})); then
      "${admin[@]}" apt-get -o Acquire::Retries=3 update
      "${admin[@]}" apt-get -o Acquire::Retries=3 install -y --no-install-recommends --no-upgrade "${missing[@]}"
    fi
    ;;
  user-install)
    [[ $EUID != 0 ]] || fail 'Run as the normal user.'
    mkdir -p "$HOME/.local/bin" "$HOME/.config"
    for pair in bat:batcat fd:fdfind; do
      name=${pair%:*}; target=/usr/bin/${pair#*:}
      [[ -e $HOME/.local/bin/$name || -L $HOME/.local/bin/$name ]] || ln -s "$target" "$HOME/.local/bin/$name"
    done
    if [[ ! -e $HOME/.config/prezto ]]; then
      git clone --no-checkout https://github.com/sorin-ionescu/prezto.git "$HOME/.config/prezto"
      git -C "$HOME/.config/prezto" checkout --detach "$prezto_revision"
      git -C "$HOME/.config/prezto" submodule update --init --recursive
    else
      [[ $(git -C "$HOME/.config/prezto" rev-parse HEAD) == "$prezto_revision" ]] || fail 'Existing Prezto version differs; review before upgrading.'
      git -C "$HOME/.config/prezto" submodule update --init --recursive
    fi
    if ! command -v yazi >/dev/null; then
      temp=$(mktemp -d); trap 'rm -rf -- "$temp"' EXIT
      [[ $(uname -m) == x86_64 ]] || fail 'Yazi download currently supports x86_64.'
      curl -fsSL --retry 3 https://github.com/sxyazi/yazi/releases/download/v26.9.1/yazi-x86_64-unknown-linux-musl.zip -o "$temp/yazi.zip"
      printf '%s  %s\n' 9b9c39decccf8cb0ff53a7d637d38f8a79d93bbd0099f4ea9c619ef6bb392f5d "$temp/yazi.zip" | sha256sum -c -
      unzip -q "$temp/yazi.zip" -d "$temp"
      install -m 755 "$temp/yazi-x86_64-unknown-linux-musl/yazi" "$HOME/.local/bin/yazi"
      install -m 755 "$temp/yazi-x86_64-unknown-linux-musl/ya" "$HOME/.local/bin/ya"
    fi
    ;;
  configure)
    [[ $EUID != 0 ]] || fail 'Run as the normal user.'
    # Use only this curated source, never initialize the full workstation dotfiles.
    # Back up differing destinations before applying; future edits require review.
    state="$HOME/.local/state/devenv-shell"
    mkdir -p "$state"
    chezmoi_args=(--config "$chezmoi_config" --persistent-state "$state/chezmoistate.boltdb" --source "$root/preferences")
    if [[ -e $state/configured ]]; then
      diff=$(chezmoi "${chezmoi_args[@]}" diff --exclude=dirs --no-pager)
      [[ -z $diff ]] || fail 'Configuration differs; review chezmoi diff before reapplying.'
    else
      backup=$(mktemp -d "$state/backup.XXXXXXXX")
      for dest in .zshenv .config/zsh .config/nvim; do
        if [[ -e $HOME/$dest || -L $HOME/$dest ]]; then
          mkdir -p "$backup/$(dirname "$dest")"
          cp -a -- "$HOME/$dest" "$backup/$dest"
        fi
      done
      mkdir -p \
        "$HOME/.config/zsh" \
        "$HOME/.config/nvim/lua/config" \
        "$HOME/.config/nvim/lua/plugins"
      chezmoi "${chezmoi_args[@]}" apply --exclude=dirs --force
      touch "$state/configured"
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
    zsh -lic 'for tool in git ssh chezmoi zsh starship eza bat fd rg fzf yazi nvim tmux; do command -v $tool || exit 1; done; [[ -n $ZPREZTODIR && -f $ZPREZTODIR/init.zsh ]] || exit 1; alias ls; alias cat; bindkey -M viins jk'
    output=$(nvim --headless '+lua assert(vim.fn.exists(":Lazy") == 2)' +qa 2>&1) || {
      printf '%s\n' "$output" >&2
      fail 'Neovim startup check failed.'
    }
    [[ $output != *'Error detected'* && $output != *'not installed'* ]] || {
      printf '%s\n' "$output" >&2
      fail 'Neovim reported an incomplete plugin setup.'
    }
    ;;
  *) echo 'Usage: bash wsl/shell-setup.sh {packages|user-install|configure|editor-install|check}' ;;
esac
