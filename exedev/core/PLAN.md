# Minimal remote core: implementation and acceptance plan

Status: preparation only. No remote image or core target has been accepted.
The inventory collector is usable independently; the bootstrap below is proposed.

## Establish access and select the image

First verify the available control integration, its target account/VM, execution
permissions, stdin/file transfer, timeout, and session behavior. Keep direct SSH
as recovery. An integration connection does not prove SSH recovery works.
Use existing credentials only. Authentication is an explicit separate step.

List existing VMs before proposing one to create or alter. Record the selected
VM, image reference/digest, image creation time if available, CPU, RAM, disk and
existing workload in private operational notes. Choose a disposable core test VM.
Do not change the account's default image or setup script.

The published [exeuntu source](https://github.com/boldsoftware/exeuntu/blob/main/Dockerfile)
inspected during preparation uses Ubuntu 24.04 and includes development stacks,
container tools and GitHub CLI. This is source evidence, not an inventory of a
running VM. A plain Ubuntu image may be a smaller starting point but must first
prove compatibility with the selected integration. Do not install duplicates or
remove inherited tools merely to make the image look minimal. Record inherited
tools separately from additions made by this recipe.

Before installing anything, run the collector through the chosen control path.
For an already authenticated SSH destination, from a Linux client:

```bash
ssh "$VM_SSH_DEST" 'bash --noprofile --norc -s' \
  < exedev/core/inventory.sh > "$PRIVATE_INVENTORY_PATH"
```

Both variables are explicit operator inputs. Store output outside the public
checkout. The collector writes no files and installs nothing. It reports native
package versions and executable locations; portable versions and ownership still
need a targeted read after reviewing those locations. It does not load personal
shell configuration or execute arbitrary discovered tool wrappers. Record absent
noninteractive PATH entries as unknown until user installation directories have
been checked. Capture sudo capability separately without requesting a password.

## Tool ownership after inventory

| Layer | Proposed responsibility |
| --- | --- |
| Native adapter | Git, OpenSSH client, Zsh, CA certificates, curl, archives and required runtime libraries; install only missing packages |
| mise | Pinned just, chezmoi, Neovim, Starship, eza, bat, fd, ripgrep, fzf, Yazi, tmux; gh and LazyGit only after checking inherited versions and owners |
| Framework installer | Recorded Prezto and lazy.nvim revisions, locked editor plugins |
| Private dotfiles | Shared Zsh/Neovim preferences, explicit `core` editor role and Diffview preferences |
| Core recipe | Target composition, inventory reconciliation, role selection, checks, diagnostic output and template evidence |
| Project profile | Runtimes, dependencies, language servers, formatters, debuggers and editor language extras; deferred |

Retain Phase 1 pins as initial candidates for shared tools. Verify their release
artifacts and platform requirements on the selected VM. Record an explicit
owner/version/path decision for each preinstalled core tool: reuse, supply a
missing tool, or propose a deliberate replacement. Do not install a second gh,
Neovim or ripgrep silently. Reproducibility includes recording inherited image
versions, not only mise pins. New gh/LazyGit/Diffview pins await that decision.

## Implementation sequence

1. Add exactly one explicit remote target after observing OS version and
   architecture. Keep `wsl-ubuntu-thin` strict. Do not relax its Ubuntu 26.04 guard
   to accommodate a different remote image. Share only the apt missing-package
   helper if a second tested Ubuntu adapter needs it.
2. Adapt the historical VM entry point into a small delegate to the new core
   target. Remove full-toolchain installation, global dotfiles apply, mandatory
   age setup and credential creation. Until replaced, it remains historical and
   must not run.
3. Extract the proven framework installation from `wsl/shell-setup.sh` into a
   shared helper with compatibility wrappers. Separate shared mise pins from
   role selection without making the core inherit the thin role. Route just
   through a validated target resolver; keep existing thin-client commands valid.
4. Generalize dotfiles application to explicit `thin` and `core` roles. Retain
   application limited to `.zshenv`, `.config/zsh`, and `.config/nvim`; support
   their XDG destinations consistently or reject unsupported custom paths before
   changing anything. Give each role distinct state, markers and restore paths.
   Preserve first managed state, stop on rerun drift and apply intentional changes
   only through the explicit apply operation. Store revision and lock digest after
   successful verification, not before.
5. Make the core editor a deliberate no-stack selection. Simply excluding the
   thin override can enable LazyVim language/build defaults. Separate shared
   no-stack restrictions from thin UI preferences. Verify chezmoi role filtering
   against destination paths and test both roles in isolated homes. An ignored
   path does not remove a previously deployed file, so role transitions need
   explicit handling or rejection.
6. Add Diffview to the core selection in dotfiles with an exact revision and lock.
   Keep shared preferences in dotfiles, future language extras in profiles. Restore
   all locked plugins during bootstrap; ordinary editor startup must not download
   plugins, parsers, language servers or tools. Validate the effective plugin
   specification as well as a silent startup. Defer annotation plugins.
7. Make `just check` fail for missing/wrong tools, configuration drift, role
   mismatch and editor failure. Make `just doctor` diagnose those states, including
   the *applied* dotfiles revision versus the checkout revision. Report shell,
   native/inherited/mise ownership and plugin lock. Checks must not rewrite
   chezmoi configuration or reconcile files; avoid copying Phase 1's write-on-check
   behavior into the remote role.

## Acceptance on the real VM

All items below are pending. Local syntax checks do not satisfy remote acceptance.
Run mutations only after approval for the specified disposable VM and recipe.

| Check | Required evidence |
| --- | --- |
| Control path | Create a scratch shell-only text transformation and test; deliberately fail a test, edit remotely, then pass; preserve command, output and exit status |
| Recovery | Connect by direct SSH independently of the integration and read the same scratch result |
| Inventory | Before/after package and tool ownership reports, image reference, no undeclared installs |
| First bootstrap | Missing private dotfiles yields a clear resumable tools-ready state; complete role application passes checks once access is supplied |
| Rerun | Second bootstrap changes no managed files, pins or backups unnecessarily; no upgrades or duplicate installations |
| Drift | Deliberately change a scratch managed file; check/rerun reject it; approved explicit apply restores it with backup |
| Diagnostics | `just check <target>` and `just doctor <target>` from explicit mise environment; wrong target/OS/role and missing checkout fail or diagnose clearly |
| Shell | New interactive and noninteractive Zsh sessions, aliases, Prezto modules, `jk`, tool discovery, XDG history and terminal resize |
| Editor | Headless and terminal startup, core role, expected plugin locks, no stack tools/downloads, keymaps and multi-file navigation |
| PR workflow | After per-VM auth, `gh pr checkout <number>` in a clean scratch clone and `gh pr status`; confirm branch/head and review diff against the real base |
| Staging | Stage and unstage a file and a hunk in LazyGit; inspect the Git index to confirm exactly the selected changes |
| Diffview | Inspect unstaged, staged and base-to-head multi-file diffs; resolve a deliberate conflict in a disposable repo and verify both file contents and cleared unmerged index entries |
| Persistence | Start work in tmux, disconnect the client, reconnect and attach to the same process/session; read the original files |
| Thin regression | Verify the previously tested thin target after shared-helper changes; no added core review or stack tooling |

[Diffview's documentation](https://github.com/sindrets/diffview.nvim) describes
revision comparisons and conflict layouts. Validate the installed pinned version
in the actual terminal rather than inferring UI success from a headless command.
Use GitHub PR discussions for formal inline feedback; no automatic posting.

## Template gate and first profile

After core acceptance, build a separate credential-free candidate from the
recorded recipe and approved image. Test credentials on a disposable instance
derived from that candidate; do not turn an authenticated VM directly into a
template. Account for inherited provider integrations and per-machine identity
state as well as home-directory credentials. Verify isolation on the copy.

Record recipe commit, native/inherited tool versions, mise pins, dotfiles commit,
plugin lock digest, image reference and acceptance results. Designation as the
known-good template is a separate approval. Preserve the prior known-good version.
Creation from a template must never update it implicitly.

Only then select one real project and review its runtime, dependency manager,
framework, tests and editor needs. uv and Bun are preferences, not installed core
requirements or a completed profile decision.
