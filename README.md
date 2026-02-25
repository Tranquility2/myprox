# myprox

Collection of scripts for Proxmox.

## Tools

| Directory | Description |
|---|---|
| [`lxc_mount_nfs/`](lxc_mount_nfs/) | Mount an NFS share into an unprivileged LXC container with proper UID/GID mapping |

## Quick Reference

### lxc_mount_nfs

Mount an NFS share into an LXC container in a single command (run as root on the Proxmox host):

```bash
./lxc_mount_nfs/update_lxc_config.sh <LXC_ID> [SOURCE_MOUNT] [UID] [GID] [USERNAME]
```

Handles idmap config, `/etc/subuid`/`subgid`, container reboot, and user creation automatically.  
See the [full documentation](lxc_mount_nfs/README.md) for details.