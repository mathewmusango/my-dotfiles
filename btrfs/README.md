# btrfs (LUKS + subvolumes + fstab)

The disk layout for this box: a single NVMe, **btrfs behind LUKS**, split into
path-named subvolumes. OS subvolumes follow `@` + the mount path with `/` → `_`; the
lab's runtime stores use short names.

Reference only — [`fstab`](fstab) is this host's `/etc/fstab`, not an installer
(the UUIDs are machine-specific, and a wrong fstab is an unbootable box).

## Layout

```
nvme0n1
├─nvme0n1p1  vfat          /boot
└─nvme0n1p2  crypto_LUKS
   └─ system (LUKS)  →  btrfs
        @                    /
        @home                /home
        @srv                 /srv
        @cache               /srv/myinfra/cache          (lab: tool cache)
        @vms                 /srv/myinfra/vms            (lab: golden + instances)
        @containers          /srv/myinfra/containers     (lab: service data)
        @podman              /srv/myinfra/podman         (lab: rootless podman store)
        @var                 /var
        @var_lib             /var/lib
        @var_lib_portables   /var/lib/portables
        @var_lib_machines    /var/lib/machines
        @var_log             /var/log
        @var_log_audit       /var/log/audit
        @var_tmp             /var/tmp
        @swap                /swap
```

## Mount options (see `fstab`)

- `noatime` everywhere.
- `compress=zstd:3` on the OS subvolumes; `compress=zstd:1` on `@containers`.
- **No compression** on `@vms`, `@podman`, `@cache`.
- Hardening: `nosuid,nodev` on `/home`, `@containers`, `@cache`; plus `noexec` on
  `/var/log`, `/var/log/audit`, `/var/tmp`, `/boot`.
- `@podman` stays **plain** — rootless container layers need device nodes + setuid.
- `@cache` is `nosuid,nodev` but **not** `noexec` (packer executes plugins from there).
- The btrfs source is the **LUKS mapper's** filesystem UUID (`blkid /dev/mapper/system`),
  not the raw partition.

## Quotas (optional)

btrfs **qgroups** cap a subvolume's size — stop a runaway build/cache/VM filling the
disk. There is no fstab option (quota is filesystem metadata, not a mount flag), so
this is a one-time enable plus per-store limits, not an installed file.

```sh
sudo btrfs quota enable --simple /            # kernel >= 6.7: cheap, no rescan
sudo btrfs qgroup limit <size> /srv/myinfra/vms
sudo btrfs qgroup limit <size> /srv/myinfra/containers
sudo btrfs qgroup show -pcre /                # inspect
sudo btrfs qgroup limit none /srv/myinfra/vms # lift
```

- `--simple` (squota) is low-overhead and needs no rescan; a bare `quota enable` is
  full per-extent accounting (costly, worse with snapshots) and triggers a rescan.
- Limits are **per subvolume**, so they cap a whole store, not one VM or container;
  Podman cannot size an individual container on btrfs overlay.
- Over-limit writes fail with ENOSPC.

## Not used

`/var/lib/machines` and `/var/lib/portables` (systemd-nspawn / portable services) are
mounted but unused — this box is KVM (libvirt) + rootless Podman.

## Recreate (terse)

```sh
# partition (GPT): p1 = ESP (~4G, EFI System), p2 = rest
sgdisk -n 1:0:+4G -t 1:ef00 -n 2:0:0 -t 2:8309 /dev/nvme0n1
mkfs.vfat -F32 /dev/nvme0n1p1
cryptsetup luksFormat /dev/nvme0n1p2          # label it so RD_LUKS_NAME=system works
cryptsetup open /dev/nvme0n1p2 system
mkfs.btrfs -L arch /dev/mapper/system

# subvolumes (mount the toplevel first)
mount -o subvolid=5 /dev/mapper/system /mnt
for s in @ @home @srv @cache @vms @containers @podman \
         @var @var_lib @var_lib_portables @var_lib_machines \
         @var_log @var_log_audit @var_tmp @swap; do
  btrfs subvolume create "/mnt/$s"
done
```

Then mount each subvolume (see `fstab`) and `systemctl daemon-reload && mount -a`.

## See also

The lab stores' purpose and tuning: `my-labs/docs/storage.md`.
