# podman (rootless containers)

[`Podman`](https://podman.io/) — a daemonless container engine: the same images and roughly the same CLI as Docker, but rootless by default and with no background service.

> **Why podman?** Containers run as the logged-in user, with no root daemon behind them — so a container cannot quietly gain root on the host. Two things here depend on it: the [`aws/`](../aws/README.md) module runs the AWS CLI as a container, and the repo's own checks run as compose services driven by `podman-compose` — see [`containers/checks/`](../containers/checks/README.md), called by [`scripts/checks/`](../scripts/checks/README.md).

## Install

**1. Install podman** (plus compose, for the check stack)

```sh
yay -S podman podman-compose
```

**2. Enable and start the rootless service** — the socket for the current user

```sh
systemctl --user enable --now podman.socket
```

**3. Verify**

```sh
podman --version
podman run --rm docker.io/library/hello-world
systemctl --user is-active podman.socket
```

## Notes

- Rootless by default; `docker.io/...` images are the same ones Docker pulls.
- Containers fork from the shell and need no daemon, but the **user socket** is what exposes the API — `systemctl --user enable --now podman.socket` enables and starts it in one go, and Docker-socket-aware tools connect through it.
- User units stop when you log out; `loginctl enable-linger $USER` keeps the socket (and any container services) running without an active session.
- `podman-compose` does not always pick up `compose.override.yaml` — pass both files explicitly with `-f`.
- If a container cannot reach the network, give it the host's network (`--network host`, or `network_mode: host` in compose).
- Files a container writes can land owned by a subordinate UID; reach them with `podman unshare`.
- Images are cached locally after the first pull, so a module's first run is the slow one.

## Storage on btrfs / a hardened host

Rootless podman keeps images and layers under `~/.local/share/containers/storage`. On a
hardened or btrfs host that is often the wrong place, so relocate it:

- **`$HOME` mounted `nosuid,nodev` breaks it** — container layers need device nodes and
  images rely on setuid binaries. Point the store at an unhardened subvolume via
  `~/.config/containers/storage.conf`:

  ```toml
  [storage]
  driver    = "overlay"
  graphroot = "/srv/containers/$UID"          # literal UID on disk, e.g. .../1000

  [storage.options.overlay]
  mount_program = "/usr/bin/fuse-overlayfs"    # btrfs: the userspace overlay
  ```

- **Changing the graphroot starts an empty store** — and copying the old one across
  *fails*: libpod's DB embeds absolute paths, so podman refuses with
  `database configuration mismatch`. Start fresh (`podman system reset --force`) rather
  than copying.
- **Short image names need `/etc/containers/registries.conf`** (from `containers-common`,
  `unqualified-search-registries = ["docker.io"]`). If it is missing podman errors with
  *"short-name … did not resolve … no containers-registries.conf"* — reinstall
  `containers-common`, or use fully-qualified names (`docker.io/…`).
- **btrfs image builds** can fail with `userxattr: no such device`; fix it with
  `mount -o remount,userxattr <fs>` on the build-context filesystem (persist in fstab).

Upstream: <https://podman.io/docs>
