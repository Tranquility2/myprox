# Mount NFS in LXC Container

Mount an NFS share into an unprivileged LXC container with proper UID/GID mapping.

## Scripts

| Script | Where to run | Purpose |
|---|---|---|
| `update_lxc_config.sh` | Proxmox host (as root) | Configures LXC idmap, mount point, restarts container, and sets up user |
| `setup_container_user.sh` | Inside the LXC (called automatically) | Creates the mapped user/group |

## Quick Start

Everything is driven from a **single command** on the Proxmox host:

```bash
chmod +x update_lxc_config.sh setup_container_user.sh
./update_lxc_config.sh <LXC_ID> [SOURCE_MOUNT] [UID] [GID] [USERNAME]
```

| Argument | Default | Description |
|---|---|---|
| `LXC_ID` | *(required)* | Container ID |
| `SOURCE_MOUNT` | `/nfs/data` | Host path to mount into the container |
| `UID` | `1028` | User ID to map through to the container |
| `GID` | `100` | Group ID to map through to the container |
| `USERNAME` | `media` | User name to create inside the container |

### Examples

```bash
# All defaults — mount /nfs/data, user 'media' UID 1028 GID 100
./update_lxc_config.sh 130

# Custom mount, user, and IDs
./update_lxc_config.sh 130 /mnt/storage/media 1030 1030 plex
```

## What the Script Does

1. **Validates** that the source mount path exists on the host.
2. **Ensures `/etc/subuid` & `/etc/subgid`** contain the required mappings for the specified UID/GID.
3. **Backs up** the existing LXC config (e.g. `130.conf.bak.20260225143000`).
4. **Updates the LXC config** with the mount point and idmap entries.
5. **Reboots the container** and waits for it to come up (30 s timeout).
6. **Pushes `setup_container_user.sh`** into the container and runs it to create the user/group.
7. **Cleans up** the temporary script from the container.

Both scripts are **idempotent** — safe to run multiple times. They require **root** and will exit with a clear error if not run as root.

A file `/mnt/data/lxc_setup_complete.txt` will be created on success.