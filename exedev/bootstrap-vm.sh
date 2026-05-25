#!/usr/bin/env bash
# bootstrap-vm.sh
#
# Minimal headless Linux dev environment bootstrap for exe.dev VMs.
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
#   - Generate SSH keys (see pre-flight below)
#   - Authenticate GitHub CLI or Claude Code
#   - Install WezTerm or any GUI tools
#
# Pre-flight (must be done manually before running):
#
#   1. SSH key for GitHub
#      exe.dev handles VM access via its own IAM layer — you do not need
#      an SSH key to access the VM itself. However you DO need one to pull
#      from a private GitHub dotfiles repo. Generate a key and add the
#      public key to GitHub before running this script.
#
#      ssh-keygen -t ed25519 -C "cenorthrup@pm.me-exedev"
#      # Add ~/.ssh/id_ed25519.pub to GitHub → Settings → SSH Keys
#
# age keys:
#   Each VM generates its own age key during bootstrap. After the script
#   completes, the public key is printed and must be added to your chezmoi
#   config as an additional recipient so this VM can decrypt dotfile secrets.
#   This allows you to track which key belongs to which machine.
#
# Usage:
#   bash bootstrap-vm.sh

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
# 2. mise
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

ok "mise ready: $(mise --version)"

# ---------------------------------------------------------------------------
# 3. chezmoi
#
# Installs to ~/.local/bin/chezmoi.
# Run from ~ to avoid installer dropping bin/ in the wrong place.
# ---------------------------------------------------------------------------

if ! command_exists chezmoi && [ ! -f "$HOME/.local/bin/chezmoi" ]; then
  info "Installing chezmoi"
  cd ~ && sh -c "$(curl -fsLS get.chezmoi.io)"
else
  info "chezmoi already installed, skipping"
fi

ok "chezmoi ready: $(~/.local/bin/chezmoi --version)"

# ---------------------------------------------------------------------------
# 4. Clone dotfiles repo
# ---------------------------------------------------------------------------

if [ ! -d "$DOTFILES_DIR" ]; then
  info "Cloning dotfiles repo"
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  info "Dotfiles repo already exists, skipping clone"
fi

# ---------------------------------------------------------------------------
# 5. Generate age key
#
# Each VM gets its own age key for secrets management. This allows tracking
# which key belongs to which machine. After bootstrap completes, the public
# key is printed — add it to your chezmoi config as an additional recipient
# so this VM can decrypt dotfile secrets.
#
# Skipped if a key already exists (e.g. on a cloned VM).
# ---------------------------------------------------------------------------

AGE_KEY="$HOME/.config/age/key.txt"

if [ ! -f "$AGE_KEY" ]; then
  info "Generating age key"
  mkdir -p "$HOME/.config/age"

  # age is installed via mise — use the shim path directly since PATH
  # may not be fully configured yet
  "$HOME/.local/share/mise/shims/age-keygen" -o "$AGE_KEY"
  chmod 600 "$AGE_KEY"
  ok "age key generated at $AGE_KEY"
else
  info "age key already exists, skipping generation"
fi

AGE_PUBLIC_KEY=$(grep "public key:" "$AGE_KEY" | awk '{print $NF}')

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
~/.local/bin/chezmoi init

info "Applying chezmoi dotfiles"
~/.local/bin/chezmoi apply

ok "Dotfiles applied"

# ---------------------------------------------------------------------------
# 8. Install mise toolchain
#
# Reads ~/.config/mise/config.toml (deployed by chezmoi above) and installs
# all tools. Rust compilation is the slowest step — expect several minutes.
# ---------------------------------------------------------------------------

info "Installing mise toolchain (this may take several minutes)"
~/.local/bin/mise install

ok "mise toolchain installed"

# ---------------------------------------------------------------------------
# 9. [OPTIONAL] Set zsh as default shell
#
# Uncomment to set zsh as default automatically.
# Requires a logout/login to take effect.
# ---------------------------------------------------------------------------

# info "Setting zsh as default shell"
# chsh -s "$(which zsh)"
# ok "Default shell set to zsh — log out and back in to activate"

# ---------------------------------------------------------------------------
# 10. Verify key tools
# ---------------------------------------------------------------------------

info "Verifying key tools"

# Reload mise shims so newly installed tools are available
eval "$("$HOME/.local/bin/mise" activate bash)"

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
  "ripgrep"
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
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ACTION REQUIRED: Add this VM's age public key to your chezmoi config"
echo "  so this machine can decrypt dotfile secrets."
echo ""
echo "  Public key: $AGE_PUBLIC_KEY"
echo ""
echo "  Add it to .chezmoi.toml.tmpl as an additional recipient:"
echo "  recipients = [\"<your-main-key>\", \"$AGE_PUBLIC_KEY\"]"
echo ""
echo "  Then re-encrypt your secrets and push to the dotfiles repo."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  - Add the age public key above to your chezmoi config"
echo "  - Start a new zsh session to activate the full environment"
echo "  - Run 'mise doctor' to verify the mise setup"
echo "  - Run 'chezmoi status' to check for any unapplied changes"
echo "  - Optionally uncomment the chsh line above to set zsh as default shell"
