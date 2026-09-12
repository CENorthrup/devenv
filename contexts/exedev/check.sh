#!/usr/bin/env bash
set -euo pipefail

[[ $(uname -s) == Linux ]] || { printf 'This target must run on Linux.\n' >&2; exit 1; }
[[ -z ${WSL_DISTRO_NAME:-} && $(uname -r) != *[Mm]icrosoft* ]] || {
  printf 'This target must run on a remote Linux VM, not WSL.\n' >&2
  exit 1
}
[[ $(cat /proc/1/comm 2>/dev/null) == exe-init || ${DEVENV_EXEDEV:-} == 1 ]] || {
  printf 'No exe.dev runtime marker was found.\n' >&2
  exit 1
}
printf 'exe.dev host: %s\n' "$(hostname)"
