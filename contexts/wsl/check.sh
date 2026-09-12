#!/usr/bin/env bash
set -euo pipefail

if [[ -z ${WSL_DISTRO_NAME:-} && $(uname -r) != *[Mm]icrosoft* ]]; then
  printf 'This target must run inside WSL.\n' >&2
  exit 1
fi

printf 'WSL distribution: %s\n' "${WSL_DISTRO_NAME:-unknown}"
