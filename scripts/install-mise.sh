#!/usr/bin/env bash
set -euo pipefail

mise_version=2026.7.13
installer_sha256=7e24785cd242e1b5b1704cdd8d877058a5dbb8eb871605858612676b640fdd7b
install_path=${MISE_INSTALL_PATH:-$HOME/.local/bin/mise}

fail() { printf '%s\n' "$*" >&2; exit 1; }

if [[ -x $install_path ]]; then
  installed_version=$($install_path --version | awk 'NR == 1 {print $1}')
  [[ $installed_version == "$mise_version" ]] || {
    fail "Existing mise version is $installed_version; expected $mise_version. Review before upgrading."
  }
  printf 'mise %s is already installed at %s.\n' "$mise_version" "$install_path"
  exit 0
fi

[[ ! -e $install_path && ! -L $install_path ]] || {
  fail "Existing mise path is not executable: $install_path"
}

temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT
installer="$temp/install.sh"
url="https://github.com/jdx/mise/releases/download/v${mise_version}/install.sh"

curl --fail --location --proto '=https' --tlsv1.2 --retry 3 "$url" -o "$installer"
printf '%s  %s\n' "$installer_sha256" "$installer" | sha256sum -c -

mkdir -p "$(dirname "$install_path")"
MISE_VERSION="v${mise_version}" \
MISE_INSTALL_PATH="$install_path" \
MISE_INSTALL_SKIP_IF_EXISTS=1 \
  sh "$installer"

installed_version=$($install_path --version | awk 'NR == 1 {print $1}')
[[ $installed_version == "$mise_version" ]] || {
  fail "mise installation reported $installed_version; expected $mise_version."
}

printf 'Installed mise %s at %s.\n' "$mise_version" "$install_path"
