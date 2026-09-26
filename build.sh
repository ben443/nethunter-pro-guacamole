#!/bin/sh
# Build Kali NetHunter Pro for the OnePlus 7 Pro (guacamole) from scratch.
#
# Requirements on the host: git, curl, patch, podman (or docker) with KVM
# access, and img2simg (android-tools).
#
# Output: kali-nethunter-pro/output/
#   *.boot-guacamole.img      boot image (USB networking/SSH)
#   *.boot-guacamole-otg.img  boot image with the USB port in host mode
#   *.rootfs.simg             root filesystem for `fastboot flash userdata`
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
NHP="$HERE/kali-nethunter-pro"
UPSTREAM="https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-pro.git"
COMMIT="$(cat "$HERE/nethunter-pro/UPSTREAM_COMMIT")"

command -v img2simg >/dev/null || { echo "img2simg not found (install android-tools)"; exit 1; }

# 1. Upstream build scripts at a known commit, plus our changes
if [ ! -d "$NHP" ]; then
	git clone "$UPSTREAM" "$NHP"
	git -C "$NHP" checkout -q "$COMMIT"
	git -C "$NHP" apply "$HERE/nethunter-pro/kali-nethunter-pro.patch"
fi

# 2. Kernel package
"$HERE/kernel/build-kernel.sh"
cp -f "$HERE"/kernel/out/linux-image-6.17.0-sm8150_*_arm64.deb "$NHP/devices/qcom/packages/"

# 3. Image (Kali rolling + Phosh)
cd "$NHP"
./build-in-container.sh -v wip -D phosh "$@"

# 4. fastboot needs an Android sparse image (the build container has no img2simg)
cd "$NHP/output"
for img in *.rootfs.img; do
	img2simg "$img" "${img%.img}.simg" 4096
done

ls -l "$NHP/output"
