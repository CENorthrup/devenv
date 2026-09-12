#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
target=${1:-wsl-ubuntu-thin}
case $target in
  wsl-ubuntu-thin) role=thin; expected_version=26.04; context=wsl ;;
  exedev-ubuntu-core) role=core; expected_version=24.04; context=exedev ;;
  *) printf 'Unsupported target: %s\n' "$target" >&2; exit 1 ;;
esac

bash "$root/contexts/$context/check.sh"
. /etc/os-release
[[ $ID == ubuntu && $VERSION_ID == "$expected_version" ]]
DEVENV_DOTFILES_ROLE="$role" bash "$root/roles/$role/configure.sh" check

[[ $(mise --version | awk 'NR == 1 {print $1}') == 2026.7.13 ]]
tools=(just chezmoi nvim starship eza bat fd rg fzf yazi tmux)
[[ $role == core ]] && tools+=(gh lazygit)
for executable in "${tools[@]}"; do mise which "$executable" >/dev/null; done

bash "$root/scripts/shell-editor-setup.sh" check
if [[ $role == core ]]; then
  output=$(nvim --headless '+lua local p=require("lazy.core.config").plugins["diffview.nvim"]; assert(p and p._.installed)' +qa 2>&1) || {
    printf '%s\nPinned Diffview is not installed for the core role.\n' "$output" >&2
    exit 1
  }
  for executable in node bun go rustc cargo docker; do
    ! command -v "$executable" >/dev/null 2>&1 || { printf 'Core unexpectedly exposes stack tool: %s\n' "$executable" >&2; exit 1; }
  done
fi
printf 'Target %s passed.\n' "$target"
