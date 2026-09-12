#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
target=${1:-wsl-ubuntu-thin}

[[ $target == wsl-ubuntu-thin ]] || {
  printf 'Unsupported target: %s\n' "$target" >&2
  exit 1
}
[[ $EUID != 0 ]] || { printf 'Run as the normal user.\n' >&2; exit 1; }

bash "$root/contexts/wsl/check.sh"
bash "$root/os/linux/distros/ubuntu/packages.sh"
bash "$root/scripts/install-mise.sh"

export PATH="$HOME/.local/bin:$PATH"
export MISE_TRUSTED_CONFIG_PATHS="$root"
cd "$root"

mise -E thin install
set +e
mise -E thin exec -- bash "$root/roles/thin/configure.sh" configure
configure_status=$?
set -e
if [[ $configure_status == 2 ]]; then
  printf '\nCore tools are ready. Clone the private dotfiles repository to\n'
  printf '%s, then run:\n' "$HOME/projects/dotfiles"
  printf '  %s\n' '~/.local/bin/mise -E thin exec -- just apply-dotfiles'
  exit 0
fi
[[ $configure_status == 0 ]] || exit "$configure_status"
mise -E thin exec -- bash "$root/scripts/check-target.sh" "$target"

printf '\n%s is ready. Open a new terminal or run `exec zsh -l`.\n' "$target"
