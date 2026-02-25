#!/bin/bash
# Usage: ./update_lxc_config.sh <LXC_ID> [SOURCE_MOUNT] [UID] [GID] [USERNAME]
#   LXC_ID        - container ID              (required)
#   SOURCE_MOUNT  - host path to mount        (default: /nfs/nasi_data)
#   UID           - user ID to map            (default: 1028)
#   GID           - group ID to map           (default: 100)
#   USERNAME      - container user name       (default: media)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

CTID=$1
SRC_MOUNT="${2:-/nfs/data}"
MAP_UID="${3:-1028}"
MAP_GID="${4:-100}"
USERNAME="${5:-media}"

CONF="/etc/pve/lxc/${CTID}.conf"

if [ -z "$CTID" ] || [ ! -f "$CONF" ]; then
    echo "Usage: $0 <LXC_ID> [SOURCE_MOUNT] [UID] [GID] [USERNAME]"
    echo "  SOURCE_MOUNT  default: /nfs/nasi_data"
    echo "  UID           default: 1028"
    echo "  GID           default: 100"
    echo "  USERNAME      default: media"
    exit 1
fi

# Pre-calculate idmap ranges
UID_AFTER=$((MAP_UID + 1))
UID_REMAINING=$((65536 - UID_AFTER))
GID_AFTER=$((MAP_GID + 1))
GID_REMAINING=$((65536 - GID_AFTER))

echo "Updating $CONF..."
echo "  Source mount : ${SRC_MOUNT} -> /mnt/data"
echo "  UID mapping  : ${MAP_UID}"
echo "  GID mapping  : ${MAP_GID}"

# 1. Remove any existing idmaps or mp0 to prevent duplicates
sed -i '/lxc.idmap/d' "$CONF"
sed -i '/mp0:/d' "$CONF"

# 2. Append the UID/GID mapping and mount
cat <<EOF >> "$CONF"
mp0: ${SRC_MOUNT},mp=/mnt/data
lxc.idmap: u 0 100000 ${MAP_UID}
lxc.idmap: u ${MAP_UID} ${MAP_UID} 1
lxc.idmap: u ${UID_AFTER} 10${UID_AFTER} ${UID_REMAINING}
lxc.idmap: g 0 100000 ${MAP_GID}
lxc.idmap: g ${MAP_GID} ${MAP_GID} 1
lxc.idmap: g ${GID_AFTER} 10${GID_AFTER} ${GID_REMAINING}
EOF

# 3. Restart the container to apply changes
echo "Restarting container $CTID..."
pct reboot "$CTID" && echo "Container $CTID restarted successfully."

# 4. Push and run setup_container_user.sh inside the container
echo "Setting up user '${USERNAME}' inside container $CTID..."
pct push "$CTID" "${SCRIPT_DIR}/setup_container_user.sh" /tmp/setup_container_user.sh
pct exec "$CTID" -- chmod +x /tmp/setup_container_user.sh
pct exec "$CTID" -- /tmp/setup_container_user.sh "${USERNAME}" "${MAP_UID}" "${MAP_GID}"