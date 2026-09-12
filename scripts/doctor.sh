#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
target=${1:-wsl-ubuntu-thin}

printf 'Target: %s\n' "$target"
printf 'Repository: %s\n' "$root"
printf 'Kernel: %s\n' "$(uname -srmo)"
. /etc/os-release
printf 'Operating system: %s %s\n' "$NAME" "$VERSION_ID"
printf 'Context: %s\n' "${WSL_DISTRO_NAME:+WSL (${WSL_DISTRO_NAME})}"
printf 'Login shell: %s\n' "$(getent passwd "$USER" | cut -d: -f7)"
printf 'mise: %s\n' "$(mise --version | head -n 1)"
printf '\nLoaded mise configuration:\n'
mise config ls
printf '\nSelected tools:\n'
mise ls --current

printf '\nConfiguration drift:\n'
mise_matches=true
for file in config.toml config.thin.toml miserc.toml; do
  if ! cmp -s "$root/mise/$file" "$HOME/.config/mise/$file"; then
    mise_matches=false
    break
  fi
done
if $mise_matches; then
  printf 'Managed mise configuration: matches repository\n'
else
  printf 'Managed mise configuration: differs from repository\n'
fi

dotfiles_source=${DEVENV_DOTFILES_SOURCE:-$HOME/projects/dotfiles}
if [[ -d $dotfiles_source ]]; then
  if bash "$root/scripts/apply-dotfiles.sh" check "$dotfiles_source" >/dev/null 2>&1; then
    printf 'Shell and Neovim dotfiles: match repository\n'
  else
    printf 'Shell and Neovim dotfiles: differ from repository\n'
  fi
else
  printf 'Shell and Neovim dotfiles: checkout missing\n'
fi

if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf '\nDevenv revision: %s\n' "$(git -C "$root" rev-parse --short HEAD)"
  if [[ -n $(git -C "$root" status --porcelain) ]]; then
    printf 'Devenv worktree: modified\n'
  else
    printf 'Devenv worktree: clean\n'
  fi
fi

if [[ -d $dotfiles_source/.git ]]; then
  printf 'Dotfiles revision: %s\n' "$(git -C "$dotfiles_source" rev-parse --short HEAD)"
else
  printf 'Dotfiles revision: not applied yet\n'
fi
