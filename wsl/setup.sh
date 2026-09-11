#!/usr/bin/env bash
# Thin Ubuntu client. Run with bash; never run the legacy wsl-bootstrap.sh.
set -euo pipefail
action=${1:-help}
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
version=2.72.1
fail() { printf '%s\n' "$*" >&2; exit 1; }
packages=(git openssh-client curl ca-certificates)
case "$action" in
  install|configure|check|upgrade-packages) ;;
  *) printf 'Usage: bash wsl/setup.sh {install|configure|check|upgrade-packages}\n'; exit 0 ;;
esac
[[ $(uname -s) == Linux ]] || fail 'Run inside Ubuntu Linux.'
. /etc/os-release
[[ $ID == ubuntu ]] || fail 'This recipe currently supports Ubuntu only.'
[[ $EUID != 0 ]] || fail 'Run as your normal Linux user; package installation uses sudo.'
if [[ $action == upgrade-packages ]]; then
  sudo apt-get -o Acquire::Retries=3 update
  sudo apt-get -o Acquire::Retries=3 install --only-upgrade "${packages[@]}"
  exit
fi
if [[ $action == install ]]; then
  missing=()
  for pkg in "${packages[@]}"; do
    if [[ $(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null || true) != 'install ok installed' ]]; then
      missing+=("$pkg")
    fi
  done
  if ((${#missing[@]})); then
    sudo apt-get -o Acquire::Retries=3 update
    sudo apt-get -o Acquire::Retries=3 install -y --no-install-recommends --no-upgrade "${missing[@]}"
  fi
  if command -v chezmoi >/dev/null 2>&1; then
    printf 'Preserving existing chezmoi: '; chezmoi --version
  elif [[ -e $HOME/.local/bin/chezmoi || -L $HOME/.local/bin/chezmoi ]]; then
    [[ -x $HOME/.local/bin/chezmoi ]] || fail 'Existing chezmoi path is not executable; inspect it manually.'
    "$HOME/.local/bin/chezmoi" --version
  else
    case $(uname -m) in x86_64) arch=amd64 ;; aarch64) arch=arm64 ;; *) fail 'Unsupported architecture.' ;; esac
    asset="chezmoi_${version}_linux-glibc_${arch}.tar.gz"
    base="https://github.com/twpayne/chezmoi/releases/download/v${version}"
    temp=$(mktemp -d)
    trap 'rm -rf -- "$temp"' EXIT
    curl --fail --location --proto '=https' --tlsv1.2 --retry 3 "$base/$asset" -o "$temp/$asset"
    curl --fail --location --proto '=https' --tlsv1.2 --retry 3 "$base/chezmoi_${version}_checksums.txt" -o "$temp/checksums"
    (cd "$temp"; awk -v name="$asset" '$2 == name {print}' checksums > selected; test "$(wc -l < selected)" -eq 1; sha256sum -c selected)
    tar -xzf "$temp/$asset" -C "$temp" chezmoi
    "$temp/chezmoi" --version
    mkdir -p "$HOME/.local/bin"
    install -m 755 "$temp/chezmoi" "$HOME/.local/bin/chezmoi"
  fi
  printf 'Installation complete. Configuration is separate: bash wsl/setup.sh configure\n'
fi
if [[ $action == configure ]]; then
  # A separate, additive snippet avoids taking ownership of existing dotfiles.
  dest="$HOME/.config/devenv/bash.sh"
  for file in "$HOME/.bashrc" "$HOME/.profile" "$dest"; do
    [[ ! -L $file ]] || fail "Refusing to modify symlink: $file"
    [[ ! -e $file || -f $file ]] || fail "Not a regular file: $file"
  done
  [[ ! -e $dest ]] || cmp -s "$root/bash.sh" "$dest" || fail "Existing $dest differs; review it manually before applying changes."
  mkdir -p "$(dirname "$dest")"
  [[ -e $dest ]] || install -m 644 "$root/bash.sh" "$dest"
  line='[ ! -r "$HOME/.config/devenv/bash.sh" ] || . "$HOME/.config/devenv/bash.sh"'
  for file in "$HOME/.bashrc" "$HOME/.profile"; do
    if ! grep -qxF "$line" "$file" 2>/dev/null; then
      if [[ -e $file ]]; then
        backup=$(mktemp "${file}.devenv-backup.XXXXXX")
        cp -p -- "$file" "$backup"
      fi
      printf '\n# Thin WSL environment\n%s\n' "$line" >> "$file"
    fi
  done
  printf 'Configuration applied. Open a new shell.\n'
fi
if [[ $action == check ]]; then
  git --version
  ssh -V
  curl --version | head -n 1
  command -v chezmoi >/dev/null || fail 'chezmoi is absent from PATH; install, configure, then open a new shell.'
  chezmoi --version
  [[ -t 0 ]] && stty size || true
  printf 'Local tools OK. Remote authentication and graphical terminal checks are separate.\n'
fi
