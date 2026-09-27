# Kali NetHunter Pro for the OnePlus 7 Pro (guacamole)

[Kali NetHunter Pro](https://www.kali.org/docs/nethunter-pro/) (Kali Linux + Phosh,
on a mainline Linux kernel instead of Android) for the **OnePlus 7 Pro**
(`guacamole`, GM1910/GM1911/GM1913/GM1917, Snapdragon 855 / SM8150).

Built on the [sm8150-mainline](https://gitlab.com/sm8150-mainline/linux) kernel
used by postmarketOS, and the official
[kali-nethunter-pro build scripts](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-pro).
Developed and tested on a GM1911 (India).

> [!WARNING]
> This is a community port and experimental. It **replaces Android** on your
> phone. Back up everything first (see [Before you start](#before-you-start)).

## Status

| Feature | Status | Notes |
| --- | --- | --- |
| Boot, Kali + Phosh | Works | |
| Display | Works | Bootloader framebuffer (simpledrm), **no GPU**: everything is software-rendered |
| Touchscreen | Works | |
| Wi-Fi (built-in) | Works | Scanning and connecting on 2.4 GHz; needs the Android 12 firmware |
| Battery level | Works | PM8150B fuel gauge; charges over USB |
| USB networking + SSH | Works | Phone is `10.66.0.1` |
| App store (Software + Flathub) | Works | Not in v0.1; build from source or `sudo apt install gnome-software gnome-software-plugin-flatpak` |
| USB OTG (host mode) | Separate boot image | Swap boot image to use USB Wi-Fi adapters etc. |
| Modem firmware | Loads | Calls/SMS/mobile data untested |
| Bluetooth, audio, camera, GPU, sensors, fingerprint | Not working | |

Performance: without a GPU driver the CPU draws every frame of a 1440×3120
panel. The image uses pixman/cairo software renderers, disables animations,
and runs the CPU governor at `performance`, which makes it usable but not
smooth, and costs battery.

## Before you start

You need:

* A OnePlus 7 Pro with an **unlocked bootloader**.
* A Linux PC with `fastboot` and `adb` (`android-tools`).
* **The final Android 12 (OxygenOS 12) firmware on both A/B slots.** The Wi-Fi
  firmware in older OxygenOS versions refuses to connect with mainline Linux,
  and the device tree uses the Android 12 memory layout.

### Back up your phone's unique partitions

`persist`, `modemst1`, `modemst2`, `fsg`, `fsc` hold your IMEI and radio
calibration. They are never touched by this port, but back them up anyway
before experimenting, e.g. from a recovery with a root adb shell:

```sh
for p in persist modemst1 modemst2 fsg fsc; do
    adb exec-out "dd if=/dev/block/by-name/$p 2>/dev/null" > $p.img
done
```

Keep these files private: they contain your IMEI.

### Get the Android 12 firmware onto both slots

The easiest way is [LineageOS](https://wiki.lineageos.org/devices/guacamole/),
which ships the Android 12 firmware:

1. Follow the LineageOS install guide for guacamole (flash its `dtbo`,
   `vbmeta` and `boot`, boot into Lineage Recovery, sideload
   `copy-partitions`, format data, sideload the LineageOS zip).
2. **In recovery, choose *Advanced → Reboot to recovery*, then sideload the
   LineageOS zip a second time.** A/B installs go to the *other* slot, so this
   puts the Android 12 firmware on both slots.
3. Optionally boot LineageOS once to check the phone works.

## Install

Download the images from the [latest release](../../releases/latest), or
[build them](#building-from-source).

1. Reboot the phone into **fastboot mode**: power off, then hold
   **Power + Volume Up**.
2. Check the downloads and unpack the rootfs (it needs ~5.4 GB):

   ```sh
   sha256sum -c SHA256SUMS
   xz -d nethunter-pro-guacamole-*.rootfs.simg.xz
   ```

3. Flash (all commands act on the **active slot**):

   ```sh
   fastboot flash boot nethunter-pro-guacamole-*.boot.img
   fastboot erase dtbo
   fastboot flash userdata nethunter-pro-guacamole-*.rootfs.simg
   fastboot reboot
   ```

   (Self-built images are named `kali-nethunterpro-*.boot-guacamole.img` and
   `kali-nethunterpro-*.rootfs.simg`.)

   `fastboot erase dtbo` is **required**: the bootloader would otherwise apply
   Android's device-tree overlays to the mainline kernel and it would crash
   instantly. Flashing `userdata` erases Android's data.
4. The first boot extracts the device's firmware (modem, Wi-Fi, DSPs) from the
   phone's own partitions and **reboots once by itself**. No proprietary
   firmware is distributed with these images.
5. Log in with user **`kali`**, password **`1234`**. Change it: `passwd`.

### SSH over USB

The phone brings up a USB network and runs an SSH server:

```sh
# on the PC (NetworkManager may also do this for you)
sudo ip addr add 10.66.0.2/24 dev usb0   # interface name may differ
ssh kali@10.66.0.1
```

### USB OTG (external Wi-Fi adapters, etc.)

The USB controller can't switch roles automatically yet. To use USB host
mode, flash the OTG boot image instead (this disables USB networking):

```sh
fastboot flash boot nethunter-pro-guacamole-*.boot-otg.img
```

Flash the normal boot image again to get USB networking back.

### Recovery

* The phone can always be put into fastboot mode with **Power + Volume Up**.
* If Kali fails to boot several times, the bootloader marks the slot
  unbootable and switches slots. Fix with
  `fastboot set_active a` (or `b`) after re-flashing.
* Do **not** run `reboot bootloader` from Linux: on this device it lands in
  Qualcomm EDL mode (`05c6:9008`). Hold Power + Volume Up for ~15 s to leave it.

## Building from source

Requirements: a Linux x86_64 host with `git`, `curl`, `patch`, `img2simg`
(`android-tools`), and **podman** (or docker) with access to `/dev/kvm`
(the image build runs in a VM via debos/fakemachine).

```sh
git clone https://github.com/haintrainn/nethunter-pro-guacamole
cd nethunter-pro-guacamole
./build.sh
```

`build.sh`:

1. clones the upstream kali-nethunter-pro build scripts at the commit in
   `nethunter-pro/UPSTREAM_COMMIT` and applies `nethunter-pro/kali-nethunter-pro.patch`;
2. builds the kernel packages with `kernel/build-kernel.sh` (downloads and
   verifies the sm8150-mainline v6.17.0 tarball, applies postmarketOS' and
   this project's patches, builds with LLVM in a Kali container);
3. builds the image (`build-in-container.sh -v wip -D phosh`);
4. converts the rootfs to an Android sparse image for fastboot.

Output lands in `kali-nethunter-pro/output/`. The first build takes about an
hour (most of it is installing packages under arm64 emulation).

## What this port changes

### Kernel (`kernel/patches/`)

| Patch | What and why |
| --- | --- |
| `0001` | Modem firmware name `.mdt` → `.mbn` (as extracted by droid-juicer); adds `sm8150-oneplus-guacamole-otg.dts` (USB host mode) |
| `0002` | guacamole device tree: `qcom,msm-id`/`board-id` so the bootloader accepts the DTB; disable `dispcc` (it reprograms the display PLL and freezes the bootloader framebuffer); framebuffer interconnect paths and physical size; enable QUP2 + GPI DMA and release the touchscreen reset GPIO; Wi-Fi supplies; PM8150B charger/fuel gauge + battery; Android 12 firmware carve-outs (160 MiB modem region) |
| `0003` | simpledrm: keep the framebuffer's `interconnects` voted so scanout isn't starved |
| `0004` | ath10k: skip the WMI quiet-mode command on WCN3990 (crashes WLAN.HL.3.x firmware) and force passive 5 GHz scans, after [this linux-wireless series](https://ratatoskr.run/linux-wireless/2026/03/15793732/t) |
| `0005` | simpledrm: report a DSI connector when the framebuffer has a `panel` node, so phoc/phosh treat the display as the built-in panel (touch mapping, rounded-corner margins in the top bar) |

`kernel/nethunter.config` switches the display to simpledrm, builds a plain
`Image.gz` for the Android bootloader, and enables common USB Wi-Fi/serial
adapters. `kernel/pmos/` holds postmarketOS' kernel config and patches.

### Image (`nethunter-pro/kali-nethunter-pro.patch`)

* `wip` device config for guacamole (boot image offsets, OTG variant, kernel
  command line `clk_ignore_unused pd_ignore_unused`).
* droid-juicer config to extract firmware on first boot.
* Enables USB networking; installs Settings, Files, Text Editor, Calculator.
* App store: GNOME Software with Flathub (Kali publishes no AppStream
  metadata, so Kali packages only show up as updates; install them with
  `apt`). Updates are not downloaded in the background.
* Phosh tuning for the framebuffer: output scale 3, pixman/cairo renderers,
  no animations, CPU `performance` governor.
* Display panel description (rounded corners) for phosh, which has none for
  guacamole, loaded through `G_RESOURCE_OVERLAYS` so the status bar icons
  aren't cut off by the screen corners.
* Fixes to the build scripts (`wip` variant, rootfs partition extraction).

## Known issues / TODO

* No GPU or proper display driver (the panel is a DSC command-mode panel).
* Bluetooth, audio, camera, sensors and fingerprint are not enabled.
* 5 GHz Wi-Fi connections are untested.
* The USB port doesn't switch between device and host mode automatically.

Contributions welcome.

## Credits

* [sm8150-mainline](https://gitlab.com/sm8150-mainline/linux) and the
  [postmarketOS](https://postmarketos.org) guacamole port.
* [Mobian](https://mobian.org) and the
  [Kali NetHunter Pro](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-pro) build scripts.
* The ath10k WCN3990 HL3.x workarounds by the author of the linked
  linux-wireless series (tested on the OnePlus 7T).
* [LineageOS](https://lineageos.org) for the firmware packaging and downstream
  device trees used as reference.

## License

Scripts, configuration and documentation in this repository:
[GPL-3.0-or-later](LICENSE), like the kali-nethunter-pro build scripts they
modify. Kernel patches (`kernel/patches/`, `kernel/pmos/`) are GPL-2.0, like
the Linux kernel.
