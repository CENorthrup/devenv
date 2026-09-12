set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Install or reconcile one supported machine target.
bootstrap target="wsl-ubuntu-thin":
    bash bootstrap/unix.sh "{{target}}"

# Apply an intentional update to the selected role configuration.
apply-role target="wsl-ubuntu-thin":
    test "{{target}}" = "wsl-ubuntu-thin"
    "$HOME/.local/bin/mise" -E thin exec -- bash roles/thin/configure.sh apply

# Verify the selected target without upgrading it.
check target="wsl-ubuntu-thin":
    test "{{target}}" = "wsl-ubuntu-thin"
    "$HOME/.local/bin/mise" -E thin exec -- bash scripts/check-target.sh "{{target}}"

# Report active versions, configuration sources, role, and drift.
doctor target="wsl-ubuntu-thin":
    test "{{target}}" = "wsl-ubuntu-thin"
    "$HOME/.local/bin/mise" -E thin exec -- bash scripts/doctor.sh "{{target}}"
