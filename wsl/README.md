# Thin Ubuntu WSL client

This profile provides a lightweight local access environment. It is tested on
Ubuntu 26.04 WSL 2, x86_64. Development runtimes, containers, language servers,
databases, and coding agents are outside this profile.

## Install

From an Ubuntu shell, run the complete entry point as the normal Linux user:

```bash
bash bootstrap/unix.sh wsl-ubuntu-thin
```

The bootstrap installs and configures:

- Ubuntu-native Git, OpenSSH client, curl, and CA certificates
- mise 2026.7.13 with just 1.58.0 and chezmoi 2.72.1
- Zsh 5.9, Prezto at the recorded commit, and Starship
- eza, bat, fd, ripgrep, fzf, Yazi 26.9.1, and tmux
- Neovim 0.11.6 with the checked-in basic LazyVim lock

The Zsh profile loads Prezto modules and the familiar aliases from the dotfiles
profile. Its vi insert mode uses `jk` to return to normal mode, and the WezTerm tab
title shows the current directory followed by `[INSERT]` or `[NORMAL]`. LazyVim
uses the same `jk` insert-mode escape mapping.

System prerequisites come from Ubuntu 26.04. Mise installs the pinned portable
tools from [`../mise/config.toml`](../mise/config.toml) and
[`../mise/config.thin.toml`](../mise/config.thin.toml). Prezto, lazy.nvim, and the
LazyVim plugin set use recorded commits. The mise installer is checked against its
recorded SHA256. Authentication remains a separate user step; the scripts create
no keys, tokens, GitHub sessions, or remote host entries.

The bootstrap is safe to rerun. Existing matching installations are preserved.
Differing managed configuration or pinned versions stop with an error for review.
On first configuration, existing Zsh and Neovim destinations are copied under
`~/.local/state/devenv-shell/backup.*` before application. The selected login shell
becomes `/usr/bin/zsh`.
The current bootstrap process cannot replace its parent shell; after it finishes,
open a new terminal or run `exec zsh -l` to enter the configured shell immediately.

## Routine commands

After the first bootstrap, run these from the repository root:

```bash
just bootstrap
just check
just doctor
```

`just bootstrap` installs missing pinned tools and preserves matching state.
`just check` is read-only. `just doctor` reports the selected target, active mise
configuration and versions, shell, repository revision, and drift. When reviewed
repository configuration intentionally changes, `just apply-role` backs up the
current managed files before applying it. Version upgrades require editing the
recorded pin and rerunning the disposable test; bootstrap never upgrades pins by
itself.

## Windows entry point

Run [`../windows/bootstrap.ps1`](../windows/bootstrap.ps1) from PowerShell to prepare
WezTerm and FiraCode Nerd Font, install Ubuntu WSL when missing, and verify Windows
prerequisites. It does not depend on winget. Windows configuration and Linux setup
remain separate so a restart or first Ubuntu user-creation prompt can be completed
before running the Linux bootstrap.

## Tests

Run the full fresh-filesystem test inside WSL as root:

```bash
sudo bash wsl/test-fresh-ubuntu.sh
```

It downloads Ubuntu Base 26.04.1, verifies the image manifest, creates an isolated
root filesystem and test user, runs the complete bootstrap twice, verifies Zsh as
the login shell, and removes the temporary filesystem. It changes no packages in
the real Ubuntu installation. It shares the WSL kernel and therefore does not test
Windows distribution import, first launch, or graphical terminal interaction.

`test.sh` remains a smaller regression test for the earlier additive Bash bootstrap.

## Acceptance after a fresh WSL install

Open a new WezTerm window and check the prompt, glyphs, copy and paste, scrolling,
resize behavior, Unicode, `yazi`, and `nvim`. Then authenticate GitHub explicitly,
clone repositories into the Linux filesystem, and test the actual exe.dev connection
when its workspace is available.
