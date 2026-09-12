#!/usr/bin/env bash
set -euo pipefail

[[ $(uname -s) == Linux ]] || { printf 'Run this on Linux.\n' >&2; exit 1; }
. /etc/os-release
[[ $ID == ubuntu && $VERSION_ID == 24.04 ]] || {
  printf 'This adapter is tested on Ubuntu 24.04; found %s %s.\n' "$ID" "$VERSION_ID" >&2
  exit 1
}

packages=(ca-certificates curl git less locales openssh-client sudo unzip xz-utils zsh)
admin=()
[[ $EUID == 0 ]] || admin=(sudo)
missing=()
for package in "${packages[@]}"; do
  [[ $(dpkg-query -W -f='${Status}' "$package" 2>/dev/null || true) == 'install ok installed' ]] || missing+=("$package")
done
if ((${#missing[@]})); then
  "${admin[@]}" apt-get -o Acquire::Retries=3 update
  "${admin[@]}" apt-get -o Acquire::Retries=3 install -y --no-install-recommends --no-upgrade "${missing[@]}"
fi
if ! locale -a | grep -qx 'en_US.utf8'; then
  "${admin[@]}" locale-gen en_US.UTF-8
fi
