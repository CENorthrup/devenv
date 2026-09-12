#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
command -v chezmoi >/dev/null
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
source_dir="$scratch/source"
mkdir -p "$source_dir/dot_config/zsh" "$source_dir/dot_config/nvim"
printf '# test shell environment\n' > "$source_dir/dot_zshenv"
printf '# test shell configuration\n' > "$source_dir/dot_config/zsh/dot_zshrc"
printf '%s\n' '-- test editor configuration' > "$source_dir/dot_config/nvim/init.lua"
for role in thin core; do
  export HOME="$scratch/$role" DEVENV_DOTFILES_ROLE="$role"
  mkdir -p "$HOME"
  (umask 002; bash "$root/scripts/apply-dotfiles.sh" apply "$source_dir")
  [[ $(stat -c %a "$HOME/.zshenv") == 644 ]]
  [[ $(stat -c %a "$HOME/.config/nvim") == 755 ]]
  for mask in 002 022 077; do
    (umask "$mask"; bash "$root/scripts/apply-dotfiles.sh" check "$source_dir")
  done
  chmod 664 "$HOME/.zshenv"
  if bash "$root/scripts/apply-dotfiles.sh" check "$source_dir" >/dev/null 2>&1; then
    printf 'Permission drift was not detected for %s\n' "$role" >&2
    exit 1
  fi
  [[ $(stat -c %a "$HOME/.zshenv") == 664 ]]
  chmod 644 "$HOME/.zshenv"
  printf '# intentional content drift\n' >> "$HOME/.config/zsh/.zshrc"
  if bash "$root/scripts/apply-dotfiles.sh" check "$source_dir" >/dev/null 2>&1; then
    printf 'Content drift was not detected for %s\n' "$role" >&2
    exit 1
  fi
  printf '%s: caller masks agree; permission and content drift rejected\n' "$role"
done
