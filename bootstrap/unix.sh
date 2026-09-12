#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
target=${1:-wsl-ubuntu-thin}
case $target in
  wsl-ubuntu-thin)
    role=thin
    context_check="$root/contexts/wsl/check.sh"
    package_install="$root/os/linux/distros/ubuntu/packages.sh"
    ;;
  exedev-ubuntu-core)
    role=core
    context_check="$root/contexts/exedev/check.sh"
    package_install="$root/os/linux/distros/ubuntu/packages-core.sh"
    ;;
  *) printf 'Unsupported target: %s\n' "$target" >&2; exit 1 ;;
esac
[[ $EUID != 0 ]] || { printf 'Run as the normal user.\n' >&2; exit 1; }

bash "$context_check"
bash "$package_install"
bash "$root/scripts/install-mise.sh"

export PATH="$HOME/.local/bin:$PATH"
export MISE_TRUSTED_CONFIG_PATHS="$root"
cd "$root"

bash "$root/scripts/configure-mise.sh" "$role" configure
mise -E "$role" install
set +e
mise -E "$role" exec -- bash "$root/roles/$role/configure.sh" configure
configure_status=$?
set -e
if [[ $configure_status == 2 ]]; then
  printf '\nCore tools are ready. Clone the private dotfiles repository to\n'
  printf '%s, then run:\n' "$HOME/projects/dotfiles"
  printf '  ~/.local/bin/mise -E %s exec -- just apply-dotfiles %s\n' "$role" "$target"
  exit 0
fi
[[ $configure_status == 0 ]] || exit "$configure_status"
mise -E "$role" exec -- bash "$root/scripts/check-target.sh" "$target"

printf '\n%s is ready. Open a new terminal or run `exec zsh -l`.\n' "$target"
