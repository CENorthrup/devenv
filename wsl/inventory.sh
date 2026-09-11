#!/usr/bin/env bash
set -eu
cat /etc/os-release
id
printf 'Shell: %s\n' "$SHELL"
for tool in git ssh curl chezmoi tmux gh mise; do
  command -v "$tool" || true
done
if [[ -x "$HOME/.local/bin/chezmoi" ]]; then "$HOME/.local/bin/chezmoi" --version; fi
dpkg-query -W git openssh-client curl ca-certificates
for file in .bashrc .profile .bash_profile .gitconfig .ssh/config .config/chezmoi/chezmoi.toml; do
  if [[ -e "$HOME/$file" ]]; then stat -c '%a %s %n' "$HOME/$file"; fi
done
if [[ -d "$HOME/.ssh" ]]; then find "$HOME/.ssh" -maxdepth 1 -type f -printf '%f\n'; fi
printf '\nShell startup configuration:\n'
for file in .bashrc .profile .bash_profile; do
  if [[ -f "$HOME/$file" ]]; then
    printf '%s\n' "$file"
    grep -nE '(^[[:space:]]*(source|\.) |PATH=|chezmoi|mise|starship|prezto)' "$HOME/$file" || true
  fi
done
printf '\nIsolation capability:\n'
unshare --user --map-root-user true && echo 'user namespaces available'
