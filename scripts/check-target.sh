#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
target=${1:-wsl-ubuntu-thin}

[[ $target == wsl-ubuntu-thin ]] || {
  printf 'Unsupported target: %s\n' "$target" >&2
  exit 1
}

bash "$root/contexts/wsl/check.sh"
. /etc/os-release
[[ $ID == ubuntu && $VERSION_ID == 26.04 ]]
bash "$root/roles/thin/configure.sh" check

[[ $(mise --version | awk 'NR == 1 {print $1}') == 2026.7.13 ]]
for executable in just chezmoi nvim starship eza bat fd rg fzf yazi tmux; do
  mise which "$executable" >/dev/null
done

bash "$root/wsl/shell-setup.sh" check
printf 'Target %s passed.\n' "$target"
