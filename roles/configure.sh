#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
role=${1:?Pass thin or core}
action=${2:-configure}
[[ $role == thin || $role == core ]] || { printf 'Unsupported role: %s\n' "$role" >&2; exit 1; }
[[ $action == configure || $action == apply || $action == check ]] || {
  printf 'Usage: %s {thin|core} {configure|apply|check}\n' "$0" >&2
  exit 1
}

bash "$root/scripts/configure-mise.sh" "$role" "$action"
export DEVENV_DOTFILES_ROLE="$role"

if [[ $action == check ]]; then
  bash "$root/scripts/apply-dotfiles.sh" check
  exit
fi

bash "$root/scripts/shell-editor-setup.sh" user-install
if [[ $action == apply ]]; then
  bash "$root/scripts/apply-dotfiles.sh" apply
else
  bash "$root/scripts/apply-dotfiles.sh" configure
fi
bash "$root/scripts/shell-editor-setup.sh" editor-install

if [[ $(getent passwd "$USER" | cut -d: -f7) != /usr/bin/zsh ]]; then
  sudo usermod --shell /usr/bin/zsh "$USER"
fi
