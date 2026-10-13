# NVIDIA (Optimus)

**Hybrid-graphics power config** — lets the discrete GPU runtime-suspend when idle and
wake on demand (CUDA, PRIME render offload).

## Files

- [`nvidia-pm.conf`](nvidia-pm.conf) — driver options: fine-grained runtime PM (`NVreg_DynamicPowerManagement=0x02`) + KMS mode-setting
- [`80-nvidia-pm.rules`](80-nvidia-pm.rules) — udev: `power/control=auto` on the NVIDIA PCI devices; removes the bundled USB controllers that block suspend
- [`install.sh`](install.sh) — copies both into `/etc` and reloads the udev rules (root)

## Setup

**1. Install the driver**

```sh
yay -S nvidia-open-dkms nvidia-utils
```

**2. Install the configs**

```sh
sudo ./nvidia/install.sh
```

**3. Enable the persistence daemon** — runtime PM does not work without it

```sh
sudo systemctl enable --now nvidia-persistenced.service
```

**4. Add the modules to the initramfs** *(recommended)*, so the options apply early

`MODULES` in `/etc/mkinitcpio.conf`:

```text
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
```

```sh
sudo mkinitcpio -P
```

**5. Verify** *(reboot first)*

```sh
nvidia-smi
# find the dGPU's PCI address with `lspci -d 10de:`
cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status   # "suspended" when idle
```

## Notes

- A Secure Boot + `lockdown=integrity` system refuses unsigned DKMS modules — remove the `lockdown=integrity` token from the kernel cmdline, or the driver will not load. Signing the modules with your Secure Boot `db` key does **not** help: the kernel verifies module signatures only against MOK keys (`.machine`), never `db` keys (`.platform`), so a `db`-signed out-of-tree module still loads as *unsigned*.
- The compositor can hold the dGPU open, leaving it `active` for a whole session rather than `suspended`.

More: [`NVIDIA Optimus`](https://wiki.archlinux.org/title/NVIDIA_Optimus)
