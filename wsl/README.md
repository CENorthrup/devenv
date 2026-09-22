# Thin Ubuntu WSL client

This profile provides a lightweight local access environment. It is tested on
Ubuntu 26.04 WSL 2, x86_64. Development runtimes, containers, language servers,
and databases are outside this profile. Codex CLI and Claude Code are intentional
thin-client tools; project runtimes remain project-owned.

Ubuntu Python 3 and OpenSSL are installed specifically for the GitHub reviewer
tooling: Python handles the review API and JSON, and OpenSSL signs App JWTs.
They are tooling prerequisites, not a managed project Python environment.

## Install

From an Ubuntu shell, run the complete entry point as the normal Linux user:

```bash
bash bootstrap/unix.sh wsl-ubuntu-thin
```

The first run installs the machine tools. If the private dotfiles checkout is not
available yet, it stops at a successful resume point and prints the next action:

```bash
mkdir -p ~/projects
git clone <private-dotfiles-url> ~/projects/dotfiles
~/.local/bin/mise -E thin exec -- just apply-dotfiles
exec zsh -l
just check
just doctor
```

GitHub authentication is an explicit prerequisite for the private clone. The
bootstrap stores no tokens or SSH keys.

The bootstrap installs and configures:

- Ubuntu-native Git, OpenSSH client, curl, and CA certificates
- Ubuntu Python 3 and OpenSSL for [reviewer tooling](../docs/github-reviewer.md)
- mise 2026.7.13 with just 1.58.0 and chezmoi 2.72.1
- Zsh 5.9, Prezto at the recorded commit, and Starship
- eza, bat, fd, ripgrep, fzf, Yazi 26.9.1, and tmux
- Neovim 0.11.6 with the basic LazyVim lock from the private dotfiles repository
- GitHub CLI 2.100.0, Codex CLI 0.155.1, and Claude Code 2.1.267

The private dotfiles repository supplies Zsh and Neovim configuration. Zsh loads
Prezto modules and the familiar aliases in an explicit order. Its vi insert mode
uses `jk` to return to normal mode, and the WezTerm tab title shows the current
directory followed by `[INSERT]` or `[NORMAL]`. LazyVim uses the same `jk`
insert-mode escape mapping.

System prerequisites come from Ubuntu 26.04. Mise installs the pinned portable
tools from [`../mise/config.toml`](../mise/config.toml) and
[`../mise/config.thin.toml`](../mise/config.thin.toml). Prezto, lazy.nvim, and the
LazyVim plugin set use recorded commits. Thin-client installation preserves the
approved editor lock between its two initial plugin-installation passes. The mise
installer is checked against its recorded SHA256. The x86_64 thin target installs native release binaries through
mise, including Codex and Claude (no npm or Node). `mise/mise.lock` and
`mise/mise.thin.lock` record the release URLs and SHA256 checksums and are deployed
only for thin.
Bootstrap uses `mise install --locked`; it never resolves `latest`. Claude
`DISABLE_AUTOUPDATER=1` and `DISABLE_UPDATES=1` are supplied by the thin mise
environment to keep upgrades under the recorded pins. Launch agents from the
configured shell or `mise -E thin exec -- <command>` so those controls apply.
Direct binary invocation outside that environment is not the managed entry path.

Authentication remains a separate user step; the scripts create
no keys, tokens, GitHub sessions, or remote host entries.

The bootstrap is safe to rerun. Existing matching installations are preserved.
Differing managed configuration or pinned versions stop with an error for review.
On first configuration, existing Zsh and Neovim destinations are copied under
`~/.local/state/devenv-dotfiles/backup.*` before application. The selected login
shell becomes `/usr/bin/zsh`.
The current bootstrap process cannot replace its parent shell; after it finishes,
open a new terminal or run `exec zsh -l` to enter the configured shell immediately.

## Routine commands

After the first bootstrap, run these from the repository root:

```bash
just bootstrap
just apply-dotfiles
just check
just doctor
```

`just bootstrap` installs missing pinned tools and preserves matching state.
`just apply-dotfiles` applies only the thin-client Zsh and Neovim selections from
`~/projects/dotfiles`.
`just check` is read-only. `just doctor` reports the selected target, active mise
configuration and versions, shell, repository revision, and drift. When reviewed
repository configuration intentionally changes, `just apply-role` backs up the
current managed files before applying it. Version upgrades require reviewing the
recorded pin and lockfile together and rerunning the disposable test; bootstrap
never upgrades pins by itself.

The thin manifest now contains environment variables, so mise requires trust for
its exact contents. Bootstrap records that trust after installation. For an
existing thin client, review the changes, run
`~/.local/bin/mise trust mise/config.thin.toml`, then `just apply-role` and
`just bootstrap` to apply configuration and install the new pins. Run
`just check` and `just doctor` in a new terminal. Checks verify the three CLI
versions and exact mise executable paths from a clean login Zsh environment,
starting in the home directory without an inherited mise PATH. Missing or
shadowing executables, missing Claude update controls, and leftover standalone
Codex or Claude installs fail verification. `doctor` reports the same checks
without authenticating.

A machine that already has Codex or Claude from their own installers (typically
`~/.local/bin/codex` and `~/.local/bin/claude`) must give ownership to mise.
The configured Zsh puts mise tools ahead of `~/.local/bin`, so the mise versions
are the ones normally run, but the standalone copies remain a second owner: they
are used by shells without mise activation and may update themselves past the
recorded pin. `just check` therefore reports them. After confirming the
mise-managed version runs, close any running session, then remove the standalone
launcher and its package directory (`~/.codex/packages/standalone`,
`~/.local/share/claude`). Credentials under `~/.codex` and `~/.claude` are
separate and are left in place.

After setup, authenticate separately with `gh auth login`, `codex`, and `claude`
as appropriate. Installation and acceptance tests do not initiate a login.

## Windows entry point

Run [`../windows/bootstrap.ps1`](../windows/bootstrap.ps1) from PowerShell to prepare
WezTerm and FiraCode Nerd Font, install Ubuntu WSL when missing, and verify Windows
prerequisites. It does not depend on winget. Windows configuration and Linux setup
remain separate so a restart or first Ubuntu user-creation prompt can be completed
before running the Linux bootstrap. WezTerm uses an explicit 10.0-point font;
`-Action Check` rejects a deployed configuration that differs from
`windows/wezterm.lua`.

## Tests

Run the full fresh-filesystem test inside WSL as root:

```bash
sudo bash wsl/test-fresh-ubuntu.sh ~/projects/dotfiles
```

It downloads Ubuntu Base 26.04.1, verifies the image manifest, creates an isolated
root filesystem and test user, tests the missing-dotfiles resume point, completes
bootstrap, reruns it, verifies Zsh as the login shell, and removes the temporary
filesystem. It verifies native CLI versions and fresh-shell paths, unchanged
tool/configuration bytes and mtimes
on rerun, no new backups, and no Node/npm or authentication credentials. It changes
no packages in the real Ubuntu installation. It shares the WSL kernel and
therefore does not test Windows distribution import, first launch, or graphical
terminal interaction.

## Acceptance after a fresh WSL install

Open a new WezTerm window and check the prompt, glyphs, copy and paste, scrolling,
resize behavior, Unicode, `yazi`, and `nvim`. Then authenticate GitHub explicitly,
clone repositories into the Linux filesystem, and test the actual exe.dev connection
when its workspace is available.

Focused verification regression test (no downloads or authentication):

```bash
bash tests/thin-tools.sh
```

The release locks were generated with mise 2026.7.13 in an isolated global
configuration using `mise -E thin lock --global --platform linux-x64`. The Claude
SHA256 was supplemented from its versioned official manifest because this mise
release's aqua metadata omits it. The existing bat and Neovim archive digests were
also completed from downloaded release artifacts. When updating pins, review
checksums as well as versions; do not deploy an automatically rewritten lockfile.
