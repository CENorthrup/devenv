#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
target=${1:-wsl-ubuntu-thin}
case $target in
  wsl-ubuntu-thin)
    role=thin
    [[ $(uname -m) == x86_64 ]] || { printf 'Thin native tools are validated on x86_64 only.\n' >&2; exit 1; }
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
if [[ $role == thin ]]; then
  mise -E thin install --locked
else
  mise -E "$role" install
fi
if [[ $role == thin ]]; then
  mise -E thin exec -- bash "$root/scripts/check-thin-tools.sh" installed
  # The thin manifest supplies update-control environment variables. Record
  # trust for these exact reviewed contents so later just/mise runs work too.
  mise trust "$root/mise/config.thin.toml"
fi
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
