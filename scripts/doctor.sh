#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
target=${1:-wsl-ubuntu-thin}
case $target in
  wsl-ubuntu-thin) role=thin; context=wsl ;;
  exedev-ubuntu-core) role=core; context=exedev ;;
  *) printf 'Unsupported target: %s\n' "$target" >&2; exit 1 ;;
esac

printf 'Target: %s\nRole: %s\nRepository: %s\n' "$target" "$role" "$root"
printf 'Kernel: %s\n' "$(uname -srmo)"
. /etc/os-release
printf 'Operating system: %s %s\nContext: %s\n' "$NAME" "$VERSION_ID" "$context"
printf 'Login shell: %s\nmise: %s\n' "$(getent passwd "$USER" | cut -d: -f7)" "$(mise --version | head -n 1)"
printf '\nLoaded mise configuration:\n'; mise config ls
printf '\nSelected tools:\n'; mise ls --current
if [[ $role == thin ]]; then
  printf '\nThin agent/GitHub tools (fresh login shell):\n'
  bash "$root/scripts/check-thin-tools.sh" doctor
fi

printf '\nConfiguration drift:\n'
if bash "$root/scripts/configure-mise.sh" "$role" check >/dev/null 2>&1; then
  printf 'Managed mise configuration: matches repository\n'
else
  printf 'Managed mise configuration: differs from repository\n'
fi

dotfiles_source=${DEVENV_DOTFILES_SOURCE:-$HOME/projects/dotfiles}
if [[ -d $dotfiles_source ]]; then
  if DEVENV_DOTFILES_ROLE="$role" bash "$root/scripts/apply-dotfiles.sh" check "$dotfiles_source" >/dev/null 2>&1; then
    printf 'Shell and Neovim dotfiles: match repository\n'
  else
    printf 'Shell and Neovim dotfiles: differ from repository\n'
  fi
else
  printf 'Shell and Neovim dotfiles: checkout missing\n'
fi

if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf '\nDevenv revision: %s\n' "$(git -C "$root" rev-parse --short HEAD)"
  [[ -z $(git -C "$root" status --porcelain) ]] && printf 'Devenv worktree: clean\n' || printf 'Devenv worktree: modified\n'
fi

marker="$HOME/.local/state/devenv-dotfiles/$role-configured"
if [[ -d $dotfiles_source/.git ]]; then
  printf 'Dotfiles checkout revision: %s\n' "$(git -C "$dotfiles_source" rev-parse --short HEAD)"
  [[ -f $marker ]] && printf 'Dotfiles applied revision: %.12s\n' "$(<"$marker")" || printf 'Dotfiles applied revision: not applied yet\n'
  sha256sum "$dotfiles_source/dot_config/nvim/lazy-lock.json" | awk '{print "Neovim lock digest: " $1}'
else
  printf 'Dotfiles revision: not applied yet\n'
fi
