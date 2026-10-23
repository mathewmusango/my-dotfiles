# my-dotfiles

**Personal Arch Linux configs.** Each app is a module: config in the repo, an install
script that copies it into place, and its own README — or, where a module only documents
a setup, just the README.

Built and used on Arch Linux — every Setup step uses `yay`, and root-owned configs land
in `/etc`.

## Screenshot

![Arch Linux desktop running KDE Plasma](assets/screenshot.jpg)

```text
my-dotfiles/
  ├── .githooks/            # pre-commit hook -> local checks
  ├── .github/              # checks.yml, codeql.yml, CODEOWNERS, dependabot
  ├── apparmor/             # MAC via the built-in LSM (install notes)
  ├── aws/                  # AWS CLI v2 via a pinned podman image
  ├── btrfs/                # LUKS + subvolumes layout, /etc/fstab reference
  ├── containers/checks/    # podman compose — one service per check
  ├── fastfetch/            # fastfetch designs: 01-minimal, 02-tree
  ├── git/                  # git itself (install notes)
  ├── gpg/                  # GnuPG agent config: common.conf, gpg-agent.conf
  ├── nerd-font/            # MesloLGS NF glyph font (install notes)
  ├── nvidia/               # Optimus power config: runtime PM + udev rules
  ├── podman/               # rootless containers (install notes)
  ├── reflector/            # Arch mirrorlist configs + daily timer override
  ├── rulesets/             # main.json + its record — the live branch ruleset
  ├── scripts/checks/       # local.sh driver + jsonc.py parser
  ├── sddm/                 # login greeter on Wayland (no root Xorg)
  ├── ssh/                  # SSH keys, host pinning and agent (docs only)
  ├── yay/                  # AUR helper (install notes)
  ├── zsh(ohmyzsh)/         # .zshrc + .p10k.zsh
  ├── CODE_OF_CONDUCT.md
  ├── CONTRIBUTING.md
  ├── LICENSE
  ├── README.md
  └── SECURITY.md
```

## Modules

| Module | Installs to | Installer |
|---|---|---|
| [`apparmor/`](apparmor/README.md) | — install notes only | — |
| [`aws/`](aws/README.md) | `~/.local/bin/aws` | `./install.sh` |
| [`btrfs/`](btrfs/README.md) | — reference: subvolume layout + `/etc/fstab` | — |
| [`fastfetch/`](fastfetch/README.md) | `~/.config/fastfetch/config.jsonc` | `./replace.sh <design>` |
| [`git/`](git/README.md) | — install notes only | — |
| [`gpg/`](gpg/README.md) | `~/.gnupg/{common,gpg-agent}.conf` (overwrites) | `./install.sh` |
| [`nerd-font/`](nerd-font/README.md) | — install notes only | — |
| [`nvidia/`](nvidia/README.md) | `/etc/modprobe.d/nvidia-pm.conf` + `/etc/udev/rules.d/80-nvidia-pm.rules` | `sudo ./install.sh` |
| [`podman/`](podman/README.md) | — install notes only | — |
| [`reflector/`](reflector/README.md) | `/etc/xdg/reflector/` + `reflector.timer` override | `sudo ./install.sh` |
| [`sddm/`](sddm/README.md) | `/etc/sddm.conf.d/10-wayland.conf` | `sudo ./install.sh` |
| [`ssh/`](ssh/README.md) | — SSH keys, host pinning, agent (nothing installed) | — |
| [`yay/`](yay/README.md) | — install notes only | — |
| [`zsh(ohmyzsh)/`](zsh(ohmyzsh)/README.md) | `~/.zshrc`, `~/.p10k.zsh` (overwrites) | `./install.sh` |

> [!WARNING]
> `gpg/` and `zsh(ohmyzsh)/` install over files that already exist at their destination.

The `02-tree` design and the p10k prompt need a Nerd Font — see [`nerd-font/`](nerd-font/README.md).

## Repository docs

Every module's README is linked in the table above. The rest of the documentation:

| Doc | Covers |
| --- | --- |
| [`.github/`](.github/INDEX.md) | the repository configuration — Dependabot, CodeQL, CODEOWNERS |
| [`rulesets/`](rulesets/README.md) | the branch ruleset, and the record beside it |
| [`containers/checks/`](containers/checks/README.md) | the compose services behind the checks |
| [`scripts/checks/`](scripts/checks/README.md) | the check driver and the pre-commit hook — run the surfaces, or the same tools locally |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) · [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) | who changes this, and the standard for any interaction |

## Setup

```sh
gh repo clone mathewmusango/my-dotfiles && cd my-dotfiles
```

Then follow the module README you need.

## Security

Report privately — see [SECURITY.md](SECURITY.md).

## License

MIT — see [LICENSE](LICENSE).
