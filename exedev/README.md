# exe.dev Dev VM Bootstrap

Bootstrap script for spinning up a headless Linux dev environment on [exe.dev](https://exe.dev).

This script is scoped to **exedev-dev** VMs. Separate bootstrap scripts exist for other VM types (e.g. exedev-server).

---

## What This Does

A single script that takes a fresh exe.dev VM from zero to a fully configured dev environment:

- Installs system packages via apt
- Installs mise and the full dev toolchain
- Installs chezmoi and applies dotfiles from the dotfiles repo
- Sets zsh as the default shell
- Generates a machine-specific age key and adds it to the chezmoi config automatically
- Verifies all tools are working

## What It Does Not Do

- Install clipboard tools, fonts, or display server packages
- Install Docker (deferred — add when needed)
- Authenticate GitHub CLI or Claude Code
- Install WezTerm or any GUI tools

---

## Pre-Flight

One step required before running the bootstrap — generate an SSH key for GitHub access.

exe.dev handles VM access via its own IAM layer — no SSH key is needed to access the VM itself. However one is needed to pull from a private GitHub dotfiles repo.

Generate the key directly on the VM after SSHing in:

```bash
ssh-keygen -t ed25519 -C "cenorthrup@pm.me-exedev-dev"
```

Add the public key to GitHub → Settings → SSH and GPG keys → New SSH key:

```bash
cat ~/.ssh/id_ed25519.pub
```

> **age keys** are generated automatically by the bootstrap script — no pre-flight needed.

> **File transfer** — if you need to copy files to the VM, `scp` is the recommended method per the exe.dev docs.

---

## Bootstrap

Once the SSH key is in place, run:

```bash
curl -fsSL https://raw.githubusercontent.com/CENorthrup/devenv/master/exedev/dev/bootstrap.sh | bash
```

The script will prompt for:
- Machine name (e.g. `exedev-dev-01`)
- Git commit name
- Git email

This will take several minutes — rust compilation is the slowest step.

---

## After Bootstrap

### 1. Log Out and Back In

Required for zsh to become the active shell:

```bash
exit
# SSH back in
```

### 2. Verify the Setup

```bash
mise doctor
chezmoi status
```

---

## exe.dev-Specific Notes

**VM access** — SSH into your VM via `ssh exe.dev` or the VM-specific address. No SSH key needed for VM access — exe.dev handles auth via its IAM layer.

**Persistent disk** — the VM's disk survives reboots and updates. The bootstrap only needs to run once.

**Clone feature** — once bootstrapped, use exe.dev's clone feature to spin up additional VMs instantly with the full environment already in place. The bootstrap script only needs to run on the first VM.

**age keys on clones** — cloned VMs share the parent VM's age key. If you want per-VM key isolation, generate a new key on the clone and update the chezmoi config:

```bash
age-keygen -o ~/.config/age/key.txt
chmod 600 ~/.config/age/key.txt
# Retrieve the public key
grep "public key:" ~/.config/age/key.txt
```

Then update `~/.config/chezmoi/chezmoi.toml` on the clone with the new recipient.

---

## Updating

After the initial bootstrap, keep things current with:

```bash
just update      # Pull latest dotfiles and apply
just upgrade     # Upgrade all mise-managed tools
```
