#!/usr/bin/env bash
set -euo pipefail
# Keep managed permissions consistent across sudo, SSH, and login shells.
umask 022

action=${1:-configure}
source_dir=${2:-${DEVENV_DOTFILES_SOURCE:-$HOME/projects/dotfiles}}
role=${DEVENV_DOTFILES_ROLE:-thin}
state_dir="$HOME/.local/state/devenv-dotfiles"
config_file="$state_dir/chezmoi.toml"
marker="$state_dir/$role-configured"

case $action in
  configure|apply|check) ;;
  *) printf 'Usage: %s {configure|apply|check} [dotfiles-source]\n' "$0" >&2; exit 1 ;;
esac
[[ $role == thin || $role == core ]] || { printf 'Unsupported dotfiles role: %s\n' "$role" >&2; exit 1; }

[[ -d $source_dir ]] || {
  printf 'Dotfiles checkout not found: %s\n' "$source_dir" >&2
  printf 'Clone the private dotfiles repository there, then run:\n' >&2
  printf '  ~/.local/bin/mise -E %s exec -- just apply-dotfiles\n' "$role" >&2
  exit 2
}

required=(
  "$source_dir/dot_zshenv"
  "$source_dir/dot_config/zsh/dot_zshrc"
  "$source_dir/dot_config/nvim/init.lua"
)
for file in "${required[@]}"; do
  [[ -f $file ]] || { printf 'Required dotfiles source is missing: %s\n' "$file" >&2; exit 1; }
done

mkdir -p "$state_dir" "$HOME/.config"
expected_config=$(mktemp "$state_dir/chezmoi.expected.XXXXXXXX")
trap 'rm -f -- "$expected_config"' EXIT
cat > "$expected_config" <<EOF
[data]
    devenvRole = "$role"
EOF

for other in thin core; do
  [[ $other == "$role" || ! -e $state_dir/$other-configured ]] || {
    printf 'Dotfiles were already applied for the %s role.\n' "$other" >&2
    exit 1
  }
done

chezmoi_args=(
  --config "$config_file"
  --persistent-state "$state_dir/chezmoistate.boltdb"
  --source "$source_dir"
)
targets=(
  "$HOME/.zshenv"
  "$HOME/.config/zsh"
  "$HOME/.config/nvim"
)

configuration_diff() {
  local managed=() managed_list path
  managed_list=$(mktemp "$state_dir/managed.XXXXXXXX")
  chezmoi "${chezmoi_args[@]}" managed > "$managed_list"
  while IFS= read -r path; do
    case $path in
      .zshenv|.config/zsh/*|.config/nvim/*) managed+=("$HOME/$path") ;;
    esac
  done < "$managed_list"
  rm -f -- "$managed_list"
  ((${#managed[@]})) || { printf 'No managed shell or Neovim files found.\n' >&2; return 1; }
  chezmoi "${chezmoi_args[@]}" diff --no-pager -- "${managed[@]}"
}

backup_destinations() {
  local backup destination relative
  backup=$(mktemp -d "$state_dir/backup.XXXXXXXX")
  for destination in "${targets[@]}"; do
    if [[ -e $destination || -L $destination ]]; then
      relative=${destination#"$HOME"/}
      mkdir -p "$backup/$(dirname "$relative")"
      cp -a -- "$destination" "$backup/$relative"
    fi
  done
}

if [[ $action == check ]]; then
  [[ -e $marker ]] || { printf '%s dotfiles have not been applied.\n' "$role" >&2; exit 1; }
  [[ -f $config_file ]] && cmp -s "$expected_config" "$config_file" || {
    printf 'Chezmoi role configuration differs from %s.\n' "$role" >&2
    exit 1
  }
  diff_output=$(configuration_diff)
  [[ -z $diff_output ]] || {
    printf 'Managed shell or Neovim configuration differs from dotfiles.\n' >&2
    exit 1
  }
  if git -C "$source_dir" rev-parse HEAD >/dev/null 2>&1; then
    [[ $(<"$marker") == "$(git -C "$source_dir" rev-parse HEAD)" ]] || {
      printf 'Applied dotfiles revision differs from the checkout.\n' >&2
      exit 1
    }
  fi
  exit
fi

if [[ $action == configure && -e $marker ]]; then
  [[ -f $config_file ]] && cmp -s "$expected_config" "$config_file" || {
    printf 'Chezmoi role configuration differs from %s.\n' "$role" >&2
    exit 1
  }
  diff_output=$(configuration_diff)
  [[ -z $diff_output ]] || {
    printf 'Managed shell or Neovim configuration differs from dotfiles.\n' >&2
    printf 'Review the diff, then run `just apply-role`.\n' >&2
    exit 1
  }
else
  backup_destinations
  install -m 600 "$expected_config" "$config_file"
  chezmoi "${chezmoi_args[@]}" apply --force -- "${targets[@]}"
  if git -C "$source_dir" rev-parse HEAD >/dev/null 2>&1; then
    git -C "$source_dir" rev-parse HEAD > "$marker"
  else
    printf 'snapshot\n' > "$marker"
  fi
fi
