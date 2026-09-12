#!/usr/bin/env bash
# Read-only pre-install inventory. Run with bash --noprofile --norc.
# Output can contain machine-specific paths; keep the report outside public Git.
set -euo pipefail

if (($#)); then
  printf 'Usage: bash exedev/core/inventory.sh\n' >&2
  exit 2
fi
[[ $(uname -s) == Linux ]] || { printf 'Linux is required.\n' >&2; exit 1; }

printf 'Inventory format: 1\nCaptured UTC: %s\n' "$(date -u +%FT%TZ)"
printf 'Kernel: %s\nArchitecture: %s\n' "$(uname -sr)" "$(uname -m)"
printf '\nOperating system:\n'
if [[ -r /etc/os-release ]]; then
  # Print data rather than sourcing the file as executable shell code.
  sed -n -E '/^(ID|VERSION_ID|PRETTY_NAME)=/p' /etc/os-release
fi
printf 'UID: %s\n' "$(id -u)"
if command -v getent >/dev/null; then
  printf 'Login shell: %s\n' "$(getent passwd "$(id -u)" | cut -d: -f7)"
fi
printf 'PID 1: %s\n' "$(cat /proc/1/comm 2>/dev/null || printf unknown)"
printf '\nRoot and home storage (mount layout does not prove persistence):\n'
df -PT / "$HOME"

# Locate all PATH matches without activating mise, sourcing personal shell files,
# starting agents, consulting credentials, or running tool install hooks.
printf '\nExecutable paths (all matches; versions follow via package metadata):\n'
for tool in bash zsh git ssh curl sudo unzip xz less mise just chezmoi nvim \
  gh lazygit starship eza bat fd fdfind rg fzf yazi tmux \
  python python3 uv node npm bun go rustc cargo docker podman \
  psql mysql sqlite3 claude codex pi shelley; do
  printf '\n%s:\n' "$tool"
  type -aP "$tool" || printf '  absent from this noninteractive PATH\n'
done

printf '\nKnown user tool directories (presence only):\n'
for relative in .local/bin .local/share/mise/installs .local/share/nvim/lazy \
  .config/mise .config/prezto .config/nvim .config/zsh; do
  if [[ -d $HOME/$relative ]]; then
    printf '%s: present\n' "$relative"
  else
    printf '%s: absent\n' "$relative"
  fi
done

printf '\nInstalled native packages (name, version, architecture):\n'
if command -v dpkg-query >/dev/null; then
  dpkg-query -W -f='${db:Status-Status}\t${binary:Package}\t${Version}\t${Architecture}\n' \
    | awk -F '\t' '$1 == "installed" { print $2 "\t" $3 "\t" $4 }' \
    | LC_ALL=C sort
else
  printf 'No dpkg-query; choose and inspect the native package adapter before installation.\n'
fi

printf '\nInventory complete. This is discovery, not core acceptance.\n'
printf 'Record the VM image reference/digest from the control plane separately.\n'
printf 'Review executable ownership and portable-tool versions before choosing pins.\n'
