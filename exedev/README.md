# exe.dev core workspace

The core target is tested on the plain Ubuntu 24.04 exe.dev image for x86_64.
It supplies repository and review tools without installing project runtimes,
containers, databases, language servers, or coding agents.

## Access and integrations

Direct SSH is the recovery path. Verify the published exe.dev host fingerprint
before adding a VM hostname to `known_hosts`. The VM-specific GitHub integration
provides repository-scoped access through `github.int.exe.xyz`; the bootstrap
does not create or store a GitHub token or SSH key.

The current core set is Git and OpenSSH, Zsh with Prezto and Starship, the shared
search/navigation tools, Neovim with pinned Diffview, GitHub CLI 2.100.0,
LazyGit 0.65.0, and tmux 3.6a. Exact portable pins are in
[`../mise/config.core.toml`](../mise/config.core.toml).

## Bootstrap

Clone this repository into a location readable by the future `exedev` user, then
run the root entry point:

```bash
bash exedev/core/bootstrap.sh
```

The entry point installs missing Ubuntu prerequisites, creates an unprivileged
`exedev` account, clones the private dotfiles repository through the scoped
integration, runs the shared `exedev-ubuntu-core` target, and sets Zsh as that
account's login shell. The account is not granted passwordless administrator
access.

Routine work runs as `exedev`:

```bash
~/.local/bin/mise -E core exec -- just check exedev-ubuntu-core
~/.local/bin/mise -E core exec -- just doctor exedev-ubuntu-core
```

Bootstrap preserves matching state and refuses configuration drift. When a
reviewed dotfiles revision changes, apply it explicitly with `just apply-role
exedev-ubuntu-core`; the existing managed files are backed up first.

The earlier [`bootstrap-vm.sh`](bootstrap-vm.sh) path remains as a compatibility
delegate to this entry point.
