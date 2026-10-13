# SDDM

**Runs the login greeter on Wayland instead of X11** — no root Xorg process, which on a
hybrid-GPU laptop also stops the greeter from holding the discrete GPU open.

## Files

- [`10-wayland.conf`](10-wayland.conf) — sets `DisplayServer=wayland`
- [`install.sh`](install.sh) — copies it into `/etc/sddm.conf.d/` (root)

## Setup

**1. Install SDDM and the Wayland greeter's dependencies**

The greeter is a Wayland client, so `DisplayServer=wayland` needs both a compositor
(SDDM's default `CompositorCommand` is `weston --shell=kiosk`) and Qt Wayland:

```sh
yay -S sddm weston qt6-wayland
```

**2. Install the config**

```sh
sudo ./sddm/install.sh
```

**3. Verify** *(after a reboot)*

```sh
ps -C Xorg                                    # empty — the greeter no longer runs Xorg
journalctl -b -t sddm -g DISPLAYSERVER_ERROR  # empty — no Wayland->X11 fallback
```

## Notes

- Without `weston` and `qt6-wayland` the Wayland greeter fails and SDDM **silently falls
  back to X11** — you keep the root Xorg process this module exists to remove, and the
  repeated failed attempts can hang the login screen. The `journalctl` line above is the tell.

More: [`SDDM`](https://wiki.archlinux.org/title/SDDM)
