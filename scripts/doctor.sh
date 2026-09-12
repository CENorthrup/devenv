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
if bash "$root/roles/thin/configure.sh" check >/dev/null 2>&1; then
  printf 'Managed mise configuration: matches repository\n'
else
  printf 'Managed mise configuration: differs from repository\n'
fi

shell_state="$HOME/.local/state/devenv-shell"
if [[ ! -e $shell_state/configured ]]; then
  printf 'Transitional shell configuration: not configured\n'
else
  shell_diff=$(chezmoi \
    --config "$root/wsl/chezmoi.toml" \
    --persistent-state "$shell_state/chezmoistate.boltdb" \
    --source "$root/wsl/preferences" \
    diff --exclude=dirs --no-pager)
  if [[ -z $shell_diff ]]; then
    printf 'Transitional shell configuration: matches repository\n'
  else
    printf 'Transitional shell configuration: differs from repository\n'
  fi
fi

if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf '\nDevenv revision: %s\n' "$(git -C "$root" rev-parse --short HEAD)"
  if [[ -n $(git -C "$root" status --porcelain) ]]; then
    printf 'Devenv worktree: modified\n'
  else
    printf 'Devenv worktree: clean\n'
  fi
fi

if [[ -d $HOME/projects/dotfiles/.git ]]; then
  printf 'Dotfiles revision: %s\n' "$(git -C "$HOME/projects/dotfiles" rev-parse --short HEAD)"
else
  printf 'Dotfiles revision: not applied yet\n'
fi
