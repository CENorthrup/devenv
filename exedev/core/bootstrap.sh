#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
user_name=${DEVENV_USER:-exedev}
dotfiles_url=${DEVENV_DOTFILES_URL:-https://github.int.exe.xyz/CENorthrup/dotfiles.git}

[[ $EUID == 0 ]] || { printf 'Run this entry point as root on the fresh VM.\n' >&2; exit 1; }
bash "$root/contexts/exedev/check.sh"
bash "$root/os/linux/distros/ubuntu/packages-core.sh"

if ! id "$user_name" >/dev/null 2>&1; then
  useradd --create-home --shell /usr/bin/bash "$user_name"
fi
user_home=$(getent passwd "$user_name" | cut -d: -f6)
install -d -o "$user_name" -g "$user_name" "$user_home/projects"
if [[ -d $user_home/projects/dotfiles/.git ]]; then
  sudo -u "$user_name" git -C "$user_home/projects/dotfiles" fetch origin master
  sudo -u "$user_name" git -C "$user_home/projects/dotfiles" checkout --detach origin/master
else
  sudo -u "$user_name" git clone --branch master --single-branch "$dotfiles_url" "$user_home/projects/dotfiles"
fi

sudo -u "$user_name" env HOME="$user_home" USER="$user_name" LOGNAME="$user_name" DEVENV_SKIP_SHELL_CHANGE=1 \
  bash "$root/bootstrap/unix.sh" exedev-ubuntu-core
usermod --shell /usr/bin/zsh "$user_name"
