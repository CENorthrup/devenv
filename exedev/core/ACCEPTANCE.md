# Core candidate acceptance

Tested 2026-09-12 on `dev-core-candidate`, a private x86_64 VM created from the
plain exe.dev Ubuntu 24.04 image with 2 CPUs, 8 GB RAM, and a 25 GB disk.
The pre-install inventory was taken before the recipe ran. This record accepts
the recipe and working candidate; it does not designate a reusable template.

## Recorded inputs

- Dotfiles revision: `c0b6febc5bcd6d7863c10c8e3cf7c2538ae095f3`
- Neovim lock SHA256: `79d26d16861f504ea31d8683b3df72ffe67fd9a25966ada596e115c145e63dcf`
- mise: 2026.7.13; just: 1.58.0; chezmoi: 2.72.1
- Neovim: 0.11.6; GitHub CLI: 2.100.0; LazyGit: 0.65.0;
  tmux: 3.6a
- The `exedev` account has no passwordless administrator access.

## Results

- First bootstrap and a second bootstrap completed successfully. The second run
  created no additional configuration backups and changed no managed files.
- `just check exedev-ubuntu-core` and `just doctor exedev-ubuntu-core` passed.
  The WSL target failed on the VM as required.
- A deliberate managed Zsh change made `just check` fail. The check left the
  change intact; restoring it made the check pass. An explicit role update
  created a backup and recorded the new dotfiles revision.
- Interactive and noninteractive Zsh startup, Prezto modules, aliases, vi `jk`,
  Neovim startup, the locked Diffview plugin, and core tool discovery passed.
- A two-file Diffview revision opened successfully. A disposable merge conflict
  produced unmerged index entries, opened in Diffview, was edited with Neovim,
  staged, and ended with the expected content and no unmerged entries.
- LazyGit staged exactly one of two hunks, then staged and unstaged the complete
  file. Direct Git index and worktree inspection confirmed each state.
- GitHub CLI queried PR status and checked out dotfiles PR #3 through the scoped
  exe.dev integration.
- A tmux process and its output survived one SSH client disconnect and were read
  through a separate SSH connection.
- A small remote script test failed deliberately, was edited on the VM, and then
  passed. Direct SSH independently read the resulting artifacts.
- Node, Bun, Go, Rust, Cargo, Docker, Python, and Python 3 remained absent.
- The complete thin target bootstrapped and reran successfully in an isolated
  Ubuntu 26.04 root filesystem after the shared-helper changes.
