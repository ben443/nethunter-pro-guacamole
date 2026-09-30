#!/bin/sh
# Build the mainline kernel for the Samsung Galaxy S20 FE 5G (r8q / SM8250)
# as Debian packages, inside a Kali container (podman or docker).
#
# Output: kernel/out/linux-image-*.deb
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC=linux-mainline-nethunter-pro
REPO="https://github.com/ben443/Linux-mainline-nethunter-pro.git"
COMMIT="$(cat "$HERE/UPSTREAM_COMMIT")"
IMAGE=kali-kernel-builder
ENGINE="${CONTAINER:-$(command -v podman >/dev/null 2>&1 && echo podman || echo docker)}"

if [ ! -d "$HERE/$SRC/.git" ]; then
	git clone --no-checkout "$REPO" "$HERE/$SRC"
fi

git -C "$HERE/$SRC" fetch --depth=1 origin "$COMMIT"
git -C "$HERE/$SRC" checkout --detach "$COMMIT"
[ "$(git -C "$HERE/$SRC" rev-parse HEAD)" = "$COMMIT" ]

for p in "$HERE"/patches/*.patch; do
	if ! git -C "$HERE/$SRC" apply --reverse --check "$p" >/dev/null 2>&1; then
		git -C "$HERE/$SRC" apply "$p"
	fi
done

if ! $ENGINE image exists "$IMAGE" 2>/dev/null &&
   ! $ENGINE image inspect "$IMAGE" >/dev/null 2>&1; then
	$ENGINE build -t "$IMAGE" -f - "$HERE" <<'EOF'
FROM docker.io/kalilinux/kali-rolling
RUN apt-get update && apt-get install -y --no-install-recommends \
	bc bison build-essential clang cpio debhelper dpkg-dev flex git kmod \
	libelf-dev libssl-dev lld llvm python3 rsync
EOF
fi

mkdir -p "$HERE/out"
rm -f "$HERE"/out/linux-image-*_arm64.deb

$ENGINE run --rm -v "$HERE:/work:z" -w "/work/$SRC" "$IMAGE" sh -ec '
	export ARCH=arm64 LLVM=1
	make defconfig
	scripts/kconfig/merge_config.sh -m .config ../nethunter.config
	make olddefconfig
	# No linux-headers package: it needs a gcc cross toolchain (we use LLVM).
	# -d: skip dpkg build-dep check (libdw-dev etc. are not needed here)
	make -j"$(nproc)" KDEB_PKGVERSION=1 DPKG_FLAGS=-d \
		DEB_BUILD_PROFILES=pkg.linux-upstream.nokernelheaders bindeb-pkg
	mkdir -p ../out
	mv ../linux-image-*_arm64.deb ../out/
	rm -f ../linux-upstream_* ../*.buildinfo ../*.changes
'

ls -l "$HERE/out"
