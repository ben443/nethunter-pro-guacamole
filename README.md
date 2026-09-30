# Kali NetHunter Pro for the Samsung Galaxy S20 FE 5G (r8q)

This repository builds an experimental Kali NetHunter Pro image for the
**Snapdragon** Samsung Galaxy S20 FE 5G (`r8q`, SM8250 / Snapdragon 865; SM-G781x).
It does not target the Exynos model.

The build combines:

* The mainline kernel source from
  [Linux-mainline-nethunter-pro](https://github.com/ben443/Linux-mainline-nethunter-pro),
  pinned by `kernel/UPSTREAM_COMMIT`. The upstream tree contains the r8q device
  tree; this project adds the simpledrm framebuffer power-domain and display
  clock protections needed to keep the firmware-initialized panel active.
* The r8q image recipes from
  [nethunter-pro-sm8450](https://github.com/ben443/nethunter-pro-sm8450), pinned
  by `nethunter-pro/UPSTREAM_COMMIT`.
* A small phoc patch that allocates offscreen buffers on the renderer's device,
  which is useful when simpledrm provides display scanout and the Adreno renders.

This is a build integration, not a tested device release or a complete flashing
guide. The r8q boot chain and partition layout differ from the previous
OnePlus/fastboot port; follow the r8q-specific instructions in the linked
NetHunter Pro repository and verify every device-specific step before flashing.
Images and kernel changes can make the phone unbootable or erase data.

## Build

The host needs Git, curl, podman or Docker with `/dev/kvm` access, and
the dependencies listed by the NetHunter Pro build repository. The kernel and
phoc packages are cross-built in containers.

```sh
./build.sh
```

The script checks out both pinned source revisions, builds an arm64 kernel
package using the upstream SM8250 config and the local `kernel/nethunter.config`
fragment, applies the local r8q simpledrm DTS patch, builds the patched phoc
package, and runs the NetHunter Pro recipe with `-t r8q -e phosh`. The local
kernel fragment enables USB gadget HID, RNDIS, serial, and mass-storage functions
alongside the r8q display, storage, and Wi-Fi settings. Build artifacts are
written into the `kali-nethunter-pro` checkout under this repository.

GitHub Actions builds the image on pushes, pull requests, and manual dispatches.
The completed image artifacts are available from the workflow run.

The kernel source currently builds at the commit recorded in
`kernel/UPSTREAM_COMMIT` (Linux 7.1.5). To update either source revision, update
its commit pin and verify that the expected r8q DTS and image-build support are
still present.

## Device limitations

The r8q mainline DTS and display setup do not imply complete hardware support.
The display path uses simpledrm and the firmware-initialized framebuffer; the
Adreno 650 needs device-specific firmware, including a Samsung-signed zap shader
from the owner's own firmware. Other device features may require additional
firmware or device-tree work. Proprietary firmware is not included here.

## License

The build scripts and configuration in this repository are GPL-3.0-or-later.
The kernel DTS patch is GPL-2.0, like the Linux kernel.
