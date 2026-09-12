# Development environments

Repeatable machine setup for a thin local WSL client and development workspaces on
exe.dev.

## Local Windows and WSL setup

Windows owns WezTerm and the terminal font. Ubuntu WSL provides a familiar shell,
navigation tools, and basic editing without local language stacks or container
infrastructure.

1. Run [`windows/bootstrap.ps1`](windows/bootstrap.ps1) from PowerShell.
2. Complete the first Ubuntu launch and create the Linux user if prompted.
3. Clone this repository to `~/projects/devenv`.
4. From Ubuntu, run `bash bootstrap/unix.sh wsl-ubuntu-thin` in this repository.
5. Authenticate GitHub, clone the private dotfiles repository to
   `~/projects/dotfiles`, and run
   `~/.local/bin/mise -E thin exec -- just apply-dotfiles` once.
6. Open a new terminal, then run `just check` and `just doctor` from this
   repository.

The first run installs pinned mise and just versions. After that, `just` is the
human-facing interface for bootstrap, verification, diagnostics, and deliberate
configuration application. See [`wsl/README.md`](wsl/README.md) for the installed
tools, safe-rerun behavior, tests, and acceptance checks.

## Composition

The current target combines these independently maintained layers:

- `os/linux/distros/ubuntu/`: Ubuntu-native prerequisites
- `contexts/wsl/`: WSL-specific validation
- `roles/thin/`: thin-client configuration
- `mise/`: pinned core and thin-role portable tools
- `targets/wsl-ubuntu-thin.toml`: the selected layer combination

The remote target reuses the role, framework, and mise layers while retaining a
separate Ubuntu 24.04 and exe.dev context guard.

## exe.dev

The `exedev-ubuntu-core` target provides the common remote workspace on a plain
Ubuntu 24.04 exe.dev VM. It installs the shared shell/editor, GitHub CLI,
LazyGit, Diffview, and persistent tmux sessions without a language stack. Run
[`exedev/core/bootstrap.sh`](exedev/core/bootstrap.sh) as root from a checkout
that the future `exedev` user can read. The entry point creates that unprivileged
user, clones the private dotfiles repository through the VM's scoped integration,
and delegates to the shared target bootstrap.

See the [core operating guide](exedev/README.md), [implementation plan](exedev/core/PLAN.md),
and [candidate acceptance record](exedev/core/ACCEPTANCE.md). The tested VM is a
working candidate; it has not been designated as a reusable template.

## Repository roles

- This repository owns machine installation, verification, VM profiles, and
  environment planning records.
- The private dotfiles repository owns personal shell and editor preferences.
  Windows WezTerm preferences remain here until its shared module is separated.
- Project repositories own dependencies, runtime constraints, locks, and build and
  test commands.

Authentication credentials and private keys are never part of reusable images or
bootstrap scripts.
