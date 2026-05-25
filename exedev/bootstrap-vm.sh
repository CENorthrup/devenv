#!/usr/bin/env bash
# bootstrap.sh
#
# Bootstrap script for exe.dev dev VMs (exedev-dev).
# Not intended for server VMs or local machines — separate bootstrap
# scripts exist for those contexts.
#
# exe.dev context:
#   - VMs are persistent — disk survives reboots and updates
#   - SSH access is handled by exe.dev's IAM layer (ssh exe.dev)
#   - Once bootstrapped, a VM can be cloned instantly via exe.dev's
#     clone feature — giving you a fully configured environment without
#     re-running this script. Run this once, then clone.
#
# What this does:
#   - Installs system packages
#   - Installs mise and the full dev toolchain
#   - Installs chezmoi and applies dotfiles from an existing repo
#   - Generates a machine-specific age key for secrets management
#   - Verifies key tools
#
# What this does NOT do:
#   - Set the default shell (marked optional below)
#   - Install clipboard tools, fonts, or display server packages
#   - Install Docker (deferred — add when needed)
#   - Authenticate GitHub CLI or Claude Code
#   - Install WezTerm or any GUI tools
#
# Pre-flight (must be done manually before running):
#
#   1. SSH key for GitHub
#      Generate directly on the VM — exe.dev handles VM access via its
#      own IAM layer so no key is needed for VM access itself. You DO
#      need one to pull from a private GitHub dotfiles repo.
#
#      ssh-keygen -t ed25519 -C "cenorthrup@pm.me-exedev-dev"
#      cat ~/.ssh/id_ed25519.pub
#      # Add the public key to GitHub → Settings → SSH and GPG keys
#
# age keys:
#   Each VM generates its own age key during bootstrap. After the script
#   completes, the public key is printed and must be added to your chezmoi
#   config as an additional recipient so this VM can decrypt dotfile secrets.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/CENorthrup/devenv/master/exedev/dev/bootstrap.sh | bash

set -euo pipefail

# ---------------------------------------------------------------------------
# Config — update before running
# ---------------------------------------------------------------------------

DOTFILES_REPO="git@github.com:CENorthrup/dotfiles.git"
DOTFILES_DIR="$HOME/.config/dotfiles"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info() { echo "==> $*"; }
ok()   { echo "    ✓ $*"; }

command_exists() { command -v "$1" &>/dev/null; }

# ---------------------------------------------------------------------------
# 1. System packages
# ---------------------------------------------------------------------------

info "Updating apt package index"
sudo apt-get update -qq

info "Installing system packages"
sudo apt-get install -y \
  git \
  curl \
  wget \
  zsh \
  unzip \
  ca-certificates \
  gnupg \
  build-essential \
  ncdu

ok "System packages installed"

# ---------------------------------------------------------------------------
# 2. PATH setup
#
# Set PATH early so all installers and binaries are findable throughout
# the script regardless of where they land. Also persist to ~/.bashrc
# so tools are findable in the shell session after the script exits.
# The permanent fix comes from the chezmoi-deployed .zshrc.
# ---------------------------------------------------------------------------

export PATH="$HOME/bin:$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

# ---------------------------------------------------------------------------
# 3. mise
#
# Installs to ~/.local/bin/mise.
# Run from ~ to avoid installer dropping bin/ in the wrong place.
# Activates temporarily for this session — permanent activation is handled
# by the chezmoi-deployed .zshrc.
# ---------------------------------------------------------------------------

if ! command_exists mise && [ ! -f "$HOME/.local/bin/mise" ]; then
  info "Installing mise"
  cd ~ && curl https://mise.run | sh
else
  info "mise already installed, skipping"
fi

info "Activating mise for this session"
eval "$("$HOME/.local/bin/mise" activate bash)"

ok "mise ready: $("$HOME/.local/bin/mise" --version)"

# ---------------------------------------------------------------------------
# 4. chezmoi
#
# Installs to ~/bin/chezmoi on exe.dev (drops bin/ relative to $HOME).
# PATH already includes ~/bin from step 2.
# ---------------------------------------------------------------------------

if ! command_exists chezmoi; then
  info "Installing chezmoi"
  cd ~ && sh -c "$(curl -fsLS get.chezmoi.io)"
else
  info "chezmoi already installed, skipping"
fi

# Resolve whichever path it landed in
CHEZMOI_BIN=$(command -v chezmoi 2>/dev/null || echo "")
if [ -z "$CHEZMOI_BIN" ]; then
  echo "ERROR: chezmoi not found after install. Check install output above."
  exit 1
fi

ok "chezmoi ready: $($CHEZMOI_BIN --version)"

# ---------------------------------------------------------------------------
# 5. Clone dotfiles repo
# ---------------------------------------------------------------------------

if [ ! -d "$DOTFILES_DIR" ]; then
  info "Cloning dotfiles repo"
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  info "Dotfiles repo already exists, skipping clone"
fi

# ---------------------------------------------------------------------------
# 6. Bootstrap chezmoi config
#
# chezmoi needs sourceDir set before init will work. Without this file,
# chezmoi init silently does nothing.
# ---------------------------------------------------------------------------

CHEZMOI_CONFIG="$HOME/.config/chezmoi/chezmoi.toml"

if [ ! -f "$CHEZMOI_CONFIG" ]; then
  info "Creating chezmoi config"
  mkdir -p "$HOME/.config/chezmoi"
  cat > "$CHEZMOI_CONFIG" <<EOF
sourceDir = "$DOTFILES_DIR"
EOF
fi

# ---------------------------------------------------------------------------
# 7. Apply chezmoi dotfiles
#
# chezmoi init runs the .chezmoi.toml.tmpl template to generate the full
# config, prompting for machine-specific values (display server, git config,
# age public key, etc.).
# chezmoi apply then writes all managed dotfiles to the home directory.
# ---------------------------------------------------------------------------

info "Running chezmoi init"
$CHEZMOI_BIN init

info "Applying chezmoi dotfiles"
$CHEZMOI_BIN apply

ok "Dotfiles applied"

# ---------------------------------------------------------------------------
# 8. Install mise toolchain
#
# Reads ~/.config/mise/config.toml (deployed by chezmoi above) and installs
# all tools. Rust compilation is the slowest step — expect several minutes.
# ---------------------------------------------------------------------------

info "Installing mise toolchain (this may take several minutes)"
"$HOME/.local/bin/mise" install

ok "mise toolchain installed"

# Reload mise shims so newly installed tools are available
eval "$("$HOME/.local/bin/mise" activate bash)"

# ---------------------------------------------------------------------------
# 9. Generate age key
#
# age is now installed via mise so the binary is available.
# Each VM gets its own age key for secrets management — allows tracking
# which key belongs to which machine.
# Skipped if a key already exists (e.g. on a cloned VM).
# After generation, the public key is added to the chezmoi config as a
# recipient so this VM can both decrypt and encrypt secrets.
# ---------------------------------------------------------------------------

AGE_KEY="$HOME/.config/age/key.txt"

if [ ! -f "$AGE_KEY" ]; then
  info "Generating age key"
  mkdir -p "$HOME/.config/age"
  age-keygen -o "$AGE_KEY"
  chmod 600 "$AGE_KEY"
  ok "age key generated at $AGE_KEY"
else
  info "age key already exists, skipping generation"
fi

AGE_PUBLIC_KEY=$(grep "public key:" "$AGE_KEY" | awk '{print $NF}')

# Add the recipient to the chezmoi config so this VM can encrypt secrets
# Only add if not already present (idempotent)
if ! grep -q "recipient" "$CHEZMOI_CONFIG"; then
  info "Adding age recipient to chezmoi config"
  cat >> "$CHEZMOI_CONFIG" <<EOF

[age]
    identity = "~/.config/age/key.txt"
    recipient = "$AGE_PUBLIC_KEY"
EOF
  ok "age recipient added to chezmoi config"
fi

# ---------------------------------------------------------------------------
# 10. Set zsh as default shell
# ---------------------------------------------------------------------------

info "Setting zsh as default shell"
chsh -s "$(which zsh)"
ok "Default shell set to zsh — log out and back in to activate"

# ---------------------------------------------------------------------------
# 11. Verify key tools
# ---------------------------------------------------------------------------

info "Verifying key tools"

TOOLS=(
  "git"
  "curl"
  "zsh"
  "mise"
  "chezmoi"
  "nvim"
  "node"
  "python3"
  "go"
  "lazygit"
  "gh"
  "just"
  "starship"
  "rg"
  "fd"
  "bat"
  "eza"
  "tmux"
  "age"
)

ALL_OK=true
for tool in "${TOOLS[@]}"; do
  if command_exists "$tool"; then
    ok "$tool: $(command -v "$tool")"
  else
    echo "    ✗ $tool: NOT FOUND"
    ALL_OK=false
  fi
done

echo ""
if [ "$ALL_OK" = true ]; then
  echo "✓ Bootstrap complete. All tools verified."
  echo ""
  echo "This VM is now ready to clone via exe.dev's clone feature."
  echo "Future VMs based on this one will have the full environment pre-installed."
else
  echo "⚠ Bootstrap complete with warnings. Some tools were not found."
  echo "  Run 'mise doctor' and 'chezmoi status' to diagnose."
fi

echo ""
echo "Next steps:"
echo "  - Log out and back in to activate zsh as your default shell"
echo "  - Run 'mise doctor' to verify the mise setup"
echo "  - Run 'chezmoi status' to check for any unapplied changes"
