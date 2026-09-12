#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
role=${1:?Pass thin or core}
action=${2:-configure}
state_dir="$HOME/.local/state/devenv"
config_dir="$HOME/.config/mise"
marker="$state_dir/mise-$role-configured"

[[ $role == thin || $role == core ]] || { printf 'Unsupported role: %s\n' "$role" >&2; exit 1; }
[[ $action == configure || $action == apply || $action == check ]] || {
  printf 'Usage: %s {thin|core} {configure|apply|check}\n' "$0" >&2
  exit 1
}

role_miserc="$root/mise/miserc.toml"
[[ $role == core ]] && role_miserc="$root/mise/miserc.core.toml"
sources=("$root/mise/config.toml" "$root/mise/config.$role.toml" "$role_miserc")
destinations=("$config_dir/config.toml" "$config_dir/config.$role.toml" "$config_dir/miserc.toml")

for other in thin core; do
  [[ $other == "$role" || ! -e $state_dir/mise-$other-configured ]] || {
    printf 'This home is already configured for the %s role.\n' "$other" >&2
    exit 1
  }
done

check_files() {
  local index
  [[ -e $marker ]] || { printf '%s mise role has not been configured.\n' "$role" >&2; return 1; }
  for index in "${!sources[@]}"; do
    [[ -f ${destinations[$index]} ]] && cmp -s "${sources[$index]}" "${destinations[$index]}" || {
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
elif [[ $action == apply || ! -e $marker ]]; then
  apply_files
else
  check_files || {
    printf 'Review the changes, then run `just apply-role`.\n' >&2
    exit 1
  }
fi
