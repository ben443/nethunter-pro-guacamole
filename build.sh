#!/bin/sh
# Build Kali NetHunter Pro for the Samsung Galaxy S20 FE 5G (r8q) from scratch.
#
# Requirements on the host: git, curl, podman (or docker) with KVM access,
# and the NetHunter Pro image build dependencies.
#
# Output: r8q boot/rootfs image artifacts under kali-nethunter-pro/
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
NHP="$HERE/kali-nethunter-pro"
UPSTREAM="https://github.com/ben443/nethunter-pro-sm8450.git"
COMMIT="$(cat "$HERE/nethunter-pro/UPSTREAM_COMMIT")"

# 1. NetHunter Pro build scripts with r8q support at a known commit
if [ ! -d "$NHP" ]; then
	git clone --no-checkout "$UPSTREAM" "$NHP"
fi
git -C "$NHP" fetch --depth=1 origin "$COMMIT"
git -C "$NHP" checkout -q --detach "$COMMIT"
[ "$(git -C "$NHP" rev-parse HEAD)" = "$COMMIT" ]

# 2. Kernel package
"$HERE/kernel/build-kernel.sh"
rm -f "$NHP"/devices/qcom/packages/r8q/linux-image-*_arm64.deb
cp -f "$HERE"/kernel/out/linux-image-*_arm64.deb "$NHP/devices/qcom/packages/r8q/"

# 3. Patched phoc (GPU thumbnails with simpledrm), installed over Kali's
"$HERE/phoc/build-phoc.sh"
rm -f "$NHP"/devices/qcom/packages/r8q/phoc_*_arm64.deb
cp -f "$HERE"/phoc/out/phoc_*_arm64.deb "$NHP/devices/qcom/packages/r8q/"

# 4. Image (Kali rolling + Phosh)
cd "$NHP"
./build.sh -t r8q -e phosh "$@"

ls -l "$NHP"/nethunterpro-*
