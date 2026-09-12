# Development environments

Repeatable machine setup for a thin local WSL client and development workspaces on
exe.dev.

## Local Windows and WSL setup

Windows owns WezTerm and the terminal font. Ubuntu WSL provides a familiar shell,
navigation tools, and basic editing without local language stacks or container
infrastructure.

1. Run [`windows/bootstrap.ps1`](windows/bootstrap.ps1) from PowerShell.
2. Complete the first Ubuntu launch and create the Linux user if prompted.
3. From Ubuntu, run `bash bootstrap/unix.sh wsl-ubuntu-thin` in this repository.
4. Authenticate GitHub explicitly, then clone working repositories into the Linux
   filesystem.

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

Future targets can reuse the Linux, role, and mise layers while replacing only the
distribution or execution-context adapter.

## exe.dev

The existing [`exedev/`](exedev/) scripts are retained while Phase 2 separates the
common remote workspace from Python and React/Node stack profiles. Do not run the
historical VM bootstrap unchanged until it has been reconciled with the current
plan.

## Repository roles

- This repository owns machine installation, verification, VM profiles, and
  environment planning records.
- The private dotfiles repository owns personal shell, editor, and terminal
  preferences once its local and remote selections are separated.
- Project repositories own dependencies, runtime constraints, locks, and build and
  test commands.

Authentication credentials and private keys are never part of reusable images or
bootstrap scripts.
