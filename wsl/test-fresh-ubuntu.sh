#!/usr/bin/env bash
# Run as root in WSL. All package changes are confined to a temporary root filesystem.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'This isolated rootfs test requires root.' >&2; exit 1; }
[[ $(uname -m) == x86_64 ]] || exit 1
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
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
cp -a "$root" "$temp/rootfs/recipe"
cat > "$temp/rootfs/recipe/inside.sh" <<'INSIDE'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get -o Acquire::Retries=3 update -qq
apt-get -o Acquire::Retries=3 install -y --no-install-recommends sudo
useradd --create-home --shell /bin/bash tester
printf 'tester ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/tester
chmod 440 /etc/sudoers.d/tester
printf '127.0.0.1 localhost %s\n' "$(hostname)" > /etc/hosts
su - tester -c 'bash /recipe/bootstrap.sh'
su - tester -c 'bash /recipe/bootstrap.sh'
test "$(getent passwd tester | cut -d: -f7)" = /usr/bin/zsh
su - tester -s /usr/bin/zsh -c 'for tool in git ssh chezmoi starship eza bat fd rg fzf yazi nvim tmux; do command -v "$tool" >/dev/null || exit 1; done'
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
chroot "$1" bash /recipe/inside.sh
NAMESPACE
