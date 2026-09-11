#!/usr/bin/env bash
# Complete thin-client setup for a fresh Ubuntu 26.04 WSL distribution.
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

[[ $(uname -s) == Linux ]] || { echo 'Run this inside Ubuntu WSL.' >&2; exit 1; }
[[ $EUID != 0 ]] || { echo 'Run this as your normal Linux user.' >&2; exit 1; }
. /etc/os-release
[[ $ID == ubuntu && $VERSION_ID == 26.04 ]] || {
  echo 'This bootstrap is tested on Ubuntu 26.04.' >&2
  exit 1
}

bash "$root/setup.sh" install
bash "$root/setup.sh" configure
bash "$root/shell-setup.sh" packages
bash "$root/shell-setup.sh" user-install
bash "$root/shell-setup.sh" configure
bash "$root/shell-setup.sh" editor-install

if [[ $(getent passwd "$USER" | cut -d: -f7) != /usr/bin/zsh ]]; then
  sudo usermod --shell /usr/bin/zsh "$USER"
fi

bash "$root/shell-setup.sh" check
printf '\nThin WSL client is ready. Open a new terminal, or run `exec zsh -l` to initialize Prezto in this window.\n'
