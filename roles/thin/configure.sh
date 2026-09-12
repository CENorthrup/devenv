#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
action=${1:-configure}
state_dir="$HOME/.local/state/devenv"
marker="$state_dir/mise-thin-configured"
config_dir="$HOME/.config/mise"

case $action in
  configure|apply|check) ;;
  *) printf 'Usage: %s {configure|apply|check}\n' "$0" >&2; exit 1 ;;
esac

sources=(
  "$root/mise/config.toml"
  "$root/mise/config.thin.toml"
  "$root/mise/miserc.toml"
)
destinations=(
  "$config_dir/config.toml"
  "$config_dir/config.thin.toml"
  "$config_dir/miserc.toml"
)

check_files() {
  local index
  for index in "${!sources[@]}"; do
    [[ -f ${destinations[$index]} ]] || {
      printf 'Missing managed mise configuration: %s\n' "${destinations[$index]}" >&2
      return 1
    }
    cmp -s "${sources[$index]}" "${destinations[$index]}" || {
      printf 'Managed mise configuration differs: %s\n' "${destinations[$index]}" >&2
      return 1
    }
  done
}

apply_files() {
  local backup index
  backup=$(mktemp -d "$state_dir/backup.mise.XXXXXXXX")
  for index in "${!sources[@]}"; do
    if [[ -e ${destinations[$index]} || -L ${destinations[$index]} ]]; then
      cp -a -- "${destinations[$index]}" "$backup/$(basename "${destinations[$index]}")"
    fi
    install -m 644 "${sources[$index]}" "${destinations[$index]}"
  done
  touch "$marker"
}

mkdir -p "$state_dir" "$config_dir"
if [[ $action == check ]]; then
  check_files
  bash "$root/scripts/apply-dotfiles.sh" check
  exit
fi

if [[ $action == apply || ! -e $marker ]]; then
  apply_files
else
  check_files || {
    printf 'Run `just apply-role wsl-ubuntu-thin` after reviewing the changes.\n' >&2
    exit 1
  }
fi

# Install frameworks here; personal shell and editor files come from dotfiles.
bash "$root/wsl/shell-setup.sh" user-install
if [[ $action == apply ]]; then
  bash "$root/scripts/apply-dotfiles.sh" apply
else
  bash "$root/scripts/apply-dotfiles.sh" configure
fi
bash "$root/wsl/shell-setup.sh" editor-install

if [[ $(getent passwd "$USER" | cut -d: -f7) != /usr/bin/zsh ]]; then
  sudo usermod --shell /usr/bin/zsh "$USER"
fi
