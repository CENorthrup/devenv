set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Install or reconcile one supported machine target.
bootstrap target="wsl-ubuntu-thin":
    bash bootstrap/unix.sh "{{target}}"

# Apply private shell and editor preferences for the selected target.
apply-dotfiles target="wsl-ubuntu-thin" source="$HOME/projects/dotfiles":
    role=$(case "{{target}}" in wsl-ubuntu-thin) echo thin;; exedev-ubuntu-core) echo core;; *) exit 1;; esac); DEVENV_DOTFILES_ROLE="$role" DEVENV_DOTFILES_SOURCE="{{source}}" bash "roles/$role/configure.sh" configure
    bash scripts/check-target.sh "{{target}}"

# Apply an intentional update to the selected role configuration.
apply-role target="wsl-ubuntu-thin":
    role=$(case "{{target}}" in wsl-ubuntu-thin) echo thin;; exedev-ubuntu-core) echo core;; *) exit 1;; esac); DEVENV_DOTFILES_ROLE="$role" bash "roles/$role/configure.sh" apply

# Verify the selected target without upgrading it.
check target="wsl-ubuntu-thin":
    bash scripts/check-target.sh "{{target}}"

# Report active versions, configuration sources, role, and drift.
doctor target="wsl-ubuntu-thin":
    bash scripts/doctor.sh "{{target}}"
