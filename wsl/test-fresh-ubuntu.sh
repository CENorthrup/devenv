#!/usr/bin/env bash
# Run as root in WSL. All package changes are confined to a temporary root filesystem.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'This isolated rootfs test requires root.' >&2; exit 1; }
[[ $(uname -m) == x86_64 ]] || exit 1
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
dotfiles_source=${1:-$HOME/projects/dotfiles}
[[ -d $dotfiles_source ]] || {
  printf 'Usage: sudo bash %s /path/to/dotfiles\n' "$0" >&2
  exit 1
}
temp=$(mktemp -d /tmp/devenv-rootfs.XXXXXXXX)
trap 'rm -rf -- "$temp"' EXIT
base=https://cdimage.ubuntu.com/ubuntu-base/releases/26.04/release
asset=ubuntu-base-26.04.1-base-amd64.tar.gz
curl -fsSL --retry 3 "$base/$asset" -o "$temp/$asset"
curl -fsSL --retry 3 "$base/SHA256SUMS" -o "$temp/SHA256SUMS"
(cd "$temp"; sha256sum --check --ignore-missing SHA256SUMS)
mkdir "$temp/rootfs"
tar -xpf "$temp/$asset" -C "$temp/rootfs"
cp --remove-destination /etc/resolv.conf "$temp/rootfs/etc/resolv.conf"
cp -a "$repo_root" "$temp/rootfs/devenv"
cp -a "$dotfiles_source" "$temp/rootfs/dotfiles"
cat > "$temp/rootfs/devenv/inside.sh" <<'INSIDE'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get -o Acquire::Retries=3 update -qq
apt-get -o Acquire::Retries=3 install -y --no-install-recommends sudo
useradd --create-home --shell /bin/bash tester
printf 'tester ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/tester
chmod 440 /etc/sudoers.d/tester
printf '127.0.0.1 localhost %s\n' "$(hostname)" > /etc/hosts
su - tester -c 'DEVENV_DOTFILES_SOURCE=/dotfiles bash /devenv/bootstrap/unix.sh wsl-ubuntu-thin'
su - tester -c 'export PATH="$HOME/.local/bin:$PATH"; export DEVENV_DOTFILES_SOURCE=/dotfiles; cd /devenv; mise -E thin exec -- just bootstrap wsl-ubuntu-thin'
test "$(getent passwd tester | cut -d: -f7)" = /usr/bin/zsh
su - tester -c '/usr/bin/zsh -lic "command -v git >/dev/null && command -v ssh >/dev/null && command -v chezmoi >/dev/null && command -v just >/dev/null && command -v starship >/dev/null && command -v eza >/dev/null && command -v bat >/dev/null && command -v fd >/dev/null && command -v rg >/dev/null && command -v fzf >/dev/null && command -v yazi >/dev/null && command -v nvim >/dev/null && command -v tmux >/dev/null"'
echo 'PASS: complete thin-client bootstrap and rerun on fresh Ubuntu.'
INSIDE
# Mounts exist only in the child namespace. Parent cleanup happens after it exits.
unshare --mount --fork bash -s -- "$temp/rootfs" <<'NAMESPACE'
set -euo pipefail
mount --make-rprivate /
mount --bind "$1" "$1"
mount -o remount,bind,suid "$1"
mount -t proc proc "$1/proc"
mount --rbind /dev "$1/dev"
mount --make-rslave "$1/dev"
chroot "$1" bash /devenv/inside.sh
NAMESPACE
