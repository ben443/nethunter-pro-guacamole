#!/bin/sh
# Build Kali's phoc with this port's patches as an arm64 Debian package,
# cross-compiled inside a Kali container (podman or docker).
#
# Output: phoc/out/phoc_*_arm64.deb
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
VERSION=0.57.0-1
LOCAL_VERSION="$VERSION+guacamole1"
POOL=http://http.kali.org/kali/pool/main/p/phoc
IMAGE=kali-phoc-cross-builder
ENGINE="${CONTAINER:-$(command -v podman >/dev/null 2>&1 && echo podman || echo docker)}"

mkdir -p "$HERE/src" "$HERE/out"
cd "$HERE/src"
for f in "phoc_$VERSION.dsc" "phoc_${VERSION%-*}.orig.tar.xz" "phoc_$VERSION.debian.tar.xz"; do
	[ -f "$f" ] || curl -fLO "$POOL/$f"
done
sha256sum -c - <<EOF
7ca7c267d0f5554ac67370d3f6406ad42fa969b3a26084df1a270366a0ddc4b1  phoc_$VERSION.dsc
fd587b1c2d3989a17f809bf5c3c234766cdf8cedce45a371357aa642cc74ef03  phoc_${VERSION%-*}.orig.tar.xz
bbb667b618050ef2338c36be47b47786bceaa637f803efd322295f3bed1fda9e  phoc_$VERSION.debian.tar.xz
EOF

if ! "$ENGINE" image exists "$IMAGE" 2>/dev/null && ! "$ENGINE" image inspect "$IMAGE" >/dev/null 2>&1; then
	"$ENGINE" build -t "$IMAGE" -f - "$HERE" <<'EOF'
FROM docker.io/kalilinux/kali-rolling
RUN dpkg --add-architecture arm64 && apt-get update && \
	apt-get install -y --no-install-recommends build-essential \
	crossbuild-essential-arm64 devscripts dpkg-dev equivs ca-certificates
EOF
fi

"$ENGINE" run --rm -v "$HERE:/work:z" -w /work "$IMAGE" sh -ec "
	apt-get update -q
	rm -rf build && mkdir build && cd build
	dpkg-source -x ../src/phoc_$VERSION.dsc phoc
	cd phoc
	# Our patches go into the package's quilt series
	mkdir -p debian/patches
	for p in /work/patches/*.patch; do
		cp \"\$p\" debian/patches/
		basename \"\$p\" >> debian/patches/series
	done
	DEBEMAIL=nobody@localhost DEBFULLNAME='nethunter-pro-guacamole' \
		dch -v $LOCAL_VERSION 'Patches for the OnePlus 7 Pro (guacamole) port.'
	apt-get build-dep -y -q -a arm64 ./
	DEB_BUILD_OPTIONS=nocheck DEB_BUILD_PROFILES='cross nocheck' \
		dpkg-buildpackage -a arm64 -b -uc -us
	cp ../phoc_${LOCAL_VERSION}_arm64.deb /work/out/
"

ls -l "$HERE/out"
