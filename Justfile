set shell := ["bash", "-euo", "pipefail", "-c"]
set positional-arguments

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

# Deploy canonical skills from the approved default-branch revision.
apply-skills:
    bash scripts/deploy-agent-skills.sh deploy

# Check deployed skills and provenance without changing them.
check-skills:
    bash scripts/deploy-agent-skills.sh check

# Explicitly deploy the current checkout into an isolated test state.
test-skills:
    bash scripts/deploy-agent-skills.sh test-deploy

# Remove the isolated feature-skill test state.
clean-test-skills:
    bash scripts/deploy-agent-skills.sh test-clean

# Exercise deployment, drift, ownership, and isolated branch-test behavior.
test-agent-skills:
    bash tests/agent-skills.sh

# Submit one App-authenticated, commit-bound review (see docs/github-reviewer.md).
submit-agent-review *args:
    bash scripts/submit-agent-review.sh "$@"

# Exercise reviewer authentication and submission offline with generated test keys.
test-agent-review:
    bash tests/agent-review.sh
