#!/usr/bin/env bash
# Disposable user environment: exercises actual downloads and config preservation.
# This shares the host OS/packages; it is not a fresh-distribution test.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT
export HOME="$temp/home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share" XDG_CACHE_HOME="$HOME/.cache"
export PATH=/usr/bin:/bin
mkdir -p "$HOME/.ssh"
printf '# Existing preferences\nalias preserved=true\n' > "$HOME/.bashrc"
printf '# Existing profile\n' > "$HOME/.profile"
printf 'test credential sentinel, not a real key\n' > "$HOME/.ssh/sentinel"
before=$(sha256sum "$HOME/.ssh/sentinel")
for file in "$root"/*.sh; do bash -n "$file"; done
bash "$root/setup.sh" install
bash "$root/setup.sh" configure
first=$(sha256sum "$HOME/.bashrc" "$HOME/.profile" "$HOME/.config/devenv/bash.sh" "$HOME/.local/bin/chezmoi")
bash "$root/setup.sh" install
bash "$root/setup.sh" configure
[[ $first == "$(sha256sum "$HOME/.bashrc" "$HOME/.profile" "$HOME/.config/devenv/bash.sh" "$HOME/.local/bin/chezmoi")" ]]
[[ $before == "$(sha256sum "$HOME/.ssh/sentinel")" ]]
grep -q 'alias preserved=true' "$HOME/.bashrc"
bash --noprofile --rcfile "$HOME/.bashrc" -ic 'command -v chezmoi; alias preserved; shopt -q checkwinsize'
. "$HOME/.profile"
bash "$root/setup.sh" check
printf '# User modification\n' >> "$HOME/.config/devenv/bash.sh"
if bash "$root/setup.sh" configure; then echo 'FAIL: edited config was overwritten'; exit 1; fi
grep -q 'User modification' "$HOME/.config/devenv/bash.sh"
printf 'PASS: install, rerun, fresh shell, credential preservation, edited-file refusal.\n'
