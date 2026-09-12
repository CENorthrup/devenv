#!/usr/bin/env bash
set -euo pipefail

action=${1:-configure}
source_dir=${2:-${DEVENV_DOTFILES_SOURCE:-$HOME/projects/dotfiles}}
state_dir="$HOME/.local/state/devenv-dotfiles"
config_file="$state_dir/chezmoi.toml"
marker="$state_dir/thin-configured"

case $action in
  configure|apply|check) ;;
  *) printf 'Usage: %s {configure|apply|check} [dotfiles-source]\n' "$0" >&2; exit 1 ;;
esac

[[ -d $source_dir ]] || {
  printf 'Dotfiles checkout not found: %s\n' "$source_dir" >&2
  printf 'Clone the private dotfiles repository there, then run:\n' >&2
  printf '  %s\n' '~/.local/bin/mise -E thin exec -- just apply-dotfiles' >&2
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
cat > "$config_file" <<'EOF'
[data]
    devenvRole = "thin"
EOF

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
  chezmoi "${chezmoi_args[@]}" diff --no-pager -- "${targets[@]}"
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
  [[ -e $marker ]] || { printf 'Thin dotfiles have not been applied.\n' >&2; exit 1; }
  [[ -z $(configuration_diff) ]] || {
    printf 'Managed shell or Neovim configuration differs from dotfiles.\n' >&2
    exit 1
  }
  exit
fi

if [[ $action == configure && -e $marker ]]; then
  [[ -z $(configuration_diff) ]] || {
    printf 'Managed shell or Neovim configuration differs from dotfiles.\n' >&2
    printf 'Review the diff, then run `just apply-role`.\n' >&2
    exit 1
  }
else
  backup_destinations
  chezmoi "${chezmoi_args[@]}" apply --force -- "${targets[@]}"
  if git -C "$source_dir" rev-parse HEAD >/dev/null 2>&1; then
    git -C "$source_dir" rev-parse HEAD > "$marker"
  else
    printf 'snapshot\n' > "$marker"
  fi
fi
