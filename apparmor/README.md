# AppArmor

**Mandatory access control from the kernel's built-in LSM** — on Arch it is two kernel
parameters and a profile package, not a kernel rebuild.

## Setup

**1. Install the tools and Arch's profiles**

```sh
yay -S apparmor
```

Tools, systemd unit, and Arch's own profiles in `/etc/apparmor.d/` — there is no separate
`apparmor-profiles` package here.

**2. Add the LSM to the kernel command line**

The stock kernel builds AppArmor in but leaves it out of `CONFIG_LSM`, so it stays inert until
the boot loader loads it. Append:

```text
apparmor=1 lsm=landlock,lockdown,yama,integrity,apparmor,bpf
```

Insert `apparmor` and keep the other members — `lsm=` replaces `CONFIG_LSM` wholesale, so
dropping `integrity` disables IMA/EVM where they are built. Arch's stock kernel builds neither,
so `integrity` and `capability` are both no-ops there: the kernel ignores a name it cannot match,
and always initialises `capability` first.

**3. Rebuild the boot image** *(unified kernel image — archinstall's default)*

Edit `/etc/kernel/cmdline`, then `sudo mkinitcpio -P`. Plain systemd-boot entries take the same
parameters on the `options:` line of the entry `bootctl list` reports as `source:` and need no
rebuild; GRUB uses `/etc/default/grub` then `grub-mkconfig`.

**4. Enable the service, reboot, verify**

```sh
sudo systemctl enable --now apparmor.service
reboot
```

```sh
cat /sys/kernel/security/lsm        # apparmor must be in the list
sudo aa-status                      # "N profiles are loaded", no filesystem error
```

`apparmor filesystem is not mounted` means the LSM never initialised — check
`cat /proc/cmdline`, and rebuild the boot image if the parameters are missing.

**5. Optional — the community profile suite**

```sh
yay -S apparmor.d
```

~700 profiles, refreshed after every `pacman` transaction by its own hook, all shipped in
**complain** mode. It brings `aa-mode`, `aa-log` and `aa-install`.

## Examples

**Firefox** — the suite's profile, and four helper profiles that are separate entries. The bare
name does not resolve, so pass the path:

```sh
sudo aa-mode -e /etc/apparmor.d/firefox.apparmor.d   # enforce
sudo aa-mode -c /etc/apparmor.d/firefox.apparmor.d   # back to complain

# its four helper profiles are separate entries, still in complain
sudo aa-mode -e /etc/apparmor.d/firefox-{crashhelper,crashreporter,pingsender,gfxtest}
```

**1Password** — its profile ships with `apparmor` and enforces itself by default. Watch it in
complain mode before trusting the log:

```sh
sudo aa-mode -c 1password    # unlock, sync, browser integration
sudo aa-log 1password        # denials, if any
sudo aa-mode -e 1password    # enforce once the log is quiet
```

**Either tool works** — `apparmor`'s own pair matches `aa-mode`: it edits the profile's flags and
reloads it, so the mode survives a reload or a reboot.

```sh
sudo aa-enforce /etc/apparmor.d/firefox.apparmor.d
sudo aa-enforce /etc/apparmor.d/1password

sudo aa-complain /etc/apparmor.d/firefox.apparmor.d
sudo aa-complain /etc/apparmor.d/1password
```

Re-check the modes after an `apparmor.d` upgrade: the package redeploys its profiles, and they
carry the suite's default mode again. Keep the paths explicit — the directory glob is the trap
below.

**Check both:**

```sh
sudo aa-status | grep -E '^ +(firefox|1password)'
sudo aa-log -s firefox       # journal; plain `aa-log` reads auditd
```

**Tuning a denial** — `aa-logprof` reads `/var/log/audit/audit.log` first (there is no journal
source in 4.1.8), so it needs `auditd` running:

```sh
yay -S audit
sudo systemctl enable --now auditd.service
```

Then complain the profile, reproduce the blocked action, and let it propose rules:

```sh
sudo aa-mode -c /etc/apparmor.d/firefox.apparmor.d
sudo aa-logprof
```

Accept into `/etc/apparmor.d/local/<name>` — every suite profile ends in
`include if exists <local/<name>>`, so the addition survives a redeploy. `aa-logprof -a` accepts
everything at once, which is how a strict profile becomes permissive.

## Notes

- No `setenforce` equivalent: mode is per profile — `sudo aa-mode -e <name>`, `sudo aa-mode -c <name>`.
- **Never** `aa-enforce /etc/apparmor.d/*`: a glob rewrites every profile file's mode in place and reloads the lot — `disable/` is bypassed, PAM helpers are included, and the change survives a reboot.
- Two files defining one profile conflict: `sudo aa-disable <name>`. Never `rm` it — `/etc/apparmor.d/<app>` belongs to the `apparmor` package and returns on upgrade.
- Blocked `sudo`? Reboot and add `apparmor=0` at the boot menu for that one boot.
- Switch a suite profile to enforce only after `aa-log` is quiet for the way you actually use it: the profiles are written for a stricter desktop than a stock KDE one, so a fresh enforce shows denials that cost features rather than block attacks.

More: [`AppArmor`](https://wiki.archlinux.org/title/AppArmor) · [`apparmor.d`](https://github.com/roddhjav/apparmor.d)
