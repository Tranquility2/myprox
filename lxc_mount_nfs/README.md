# Mount NFS in LXC Container

Mount an NFS share into an unprivileged LXC container with proper UID/GID mapping.

## Scripts

| Script | Where to run | Purpose |
|---|---|---|
| `update_lxc_config.sh` | Proxmox host | Configures LXC idmap and mount point |
| `setup_container_user.sh` | Inside the LXC | Creates the mapped user |

## Steps

### 1. On the Proxmox Host

```bash
chmod +x update_lxc_config.sh
./update_lxc_config.sh <LXC_ID> [SOURCE_MOUNT] [UID] [GID]
```

| Argument | Default | Description |
|---|---|---|
| `LXC_ID` | *(required)* | Container ID |
| `SOURCE_MOUNT` | `/nfs/data` | Host path to mount into the container |
| `UID` | `1028` | User ID to map through to the container |
| `GID` | `100` | Group ID to map through to the container |

**Examples:**

```bash
# Defaults: mount /nfs/data with UID 1028, GID 100
./update_lxc_config.sh 130

# Custom source mount and IDs
./update_lxc_config.sh 130 /mnt/storage/media 1030 1030
```

Then start (or restart) the container:

```bash
pct start <LXC_ID>
```

### 2. Inside the LXC Container

```bash
chmod +x setup_container_user.sh
./setup_container_user.sh [USERNAME] [UID] [GID]
```

| Argument | Default | Description |
|---|---|---|
| `USERNAME` | `media` | Name for the new user |
| `UID` | `1028` | User ID (must match the host-side NFS mapping) |
| `GID` | `100` | Group ID (`users` group) |

**Examples:**

```bash
# Use all defaults (user 'media', UID 1028, GID 100)
./setup_container_user.sh

# Custom user
./setup_container_user.sh plex 1030 1030
```

A file `/mnt/data/lxc_setup_complete.txt` will be created on success.