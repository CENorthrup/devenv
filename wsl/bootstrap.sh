#!/usr/bin/env bash
# Compatibility entry point for the WSL Ubuntu thin-client target.
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec bash "$root/../bootstrap/unix.sh" wsl-ubuntu-thin
