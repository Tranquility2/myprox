#!/bin/bash
set -euo pipefail

# Usage: ./update_lxc_config.sh <LXC_ID> [SOURCE_MOUNT] [UID] [GID] [USERNAME]
#   LXC_ID        - container ID              (required)
#   SOURCE_MOUNT  - host path to mount        (default: /nfs/data)
#   UID           - user ID to map            (default: 1028)
#   GID           - group ID to map           (default: 100)
#   USERNAME      - container user name       (default: media)

# -- Colours -------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Colour

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# -- Root check ----------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root."
    exit 1
fi

# -- Arguments -----------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

CTID="${1:-}"
SRC_MOUNT="${2:-/nfs/data}"
MAP_UID="${3:-1028}"
MAP_GID="${4:-100}"
USERNAME="${5:-media}"

CONF="/etc/pve/lxc/${CTID}.conf"

if [[ -z "$CTID" ]] || [[ ! -f "$CONF" ]]; then
    echo "Usage: $0 <LXC_ID> [SOURCE_MOUNT] [UID] [GID] [USERNAME]"
    echo "  SOURCE_MOUNT  default: /nfs/data"
    echo "  UID           default: 1028"
    echo "  GID           default: 100"
    echo "  USERNAME      default: media"
    exit 1
fi

# -- Validate source mount exists on host --------------------------------------
if [[ ! -d "$SRC_MOUNT" ]]; then
    error "Source mount path '${SRC_MOUNT}' does not exist on the host."
    exit 1
fi

# -- Ensure /etc/subuid & /etc/subgid entries ----------------------------------
ensure_subid() {
    local file="$1" id="$2"
    if ! grep -qE "^root:${id}:1$" "$file" 2>/dev/null; then
        warn "Adding mapping root:${id}:1 to ${file}"
        echo "root:${id}:1" >> "$file"
    fi
}

ensure_subid /etc/subuid "$MAP_UID"
ensure_subid /etc/subgid "$MAP_GID"

# -- Pre-calculate idmap ranges ------------------------------------------------
UID_AFTER=$((MAP_UID + 1))
UID_REMAINING=$((65536 - UID_AFTER))
UID_HOST_AFTER=$((100000 + UID_AFTER))
GID_AFTER=$((MAP_GID + 1))
GID_REMAINING=$((65536 - GID_AFTER))
GID_HOST_AFTER=$((100000 + GID_AFTER))

# -- Backup existing config ----------------------------------------------------
BACKUP="${CONF}.bak.$(date +%Y%m%d%H%M%S)"
cp "$CONF" "$BACKUP"
info "Config backed up to ${BACKUP}"

# -- Update LXC config ---------------------------------------------------------
info "Updating $CONF..."
info "  Source mount : ${SRC_MOUNT} -> /mnt/data"
info "  UID mapping  : ${MAP_UID}"
info "  GID mapping  : ${MAP_GID}"
info "  Username     : ${USERNAME}"

# 1. Remove any existing idmaps or mp0 to prevent duplicates
sed -i '/lxc.idmap/d' "$CONF"
sed -i '/mp0:/d' "$CONF"

# 2. Append the UID/GID mapping and mount
cat <<EOF >> "$CONF"
mp0: ${SRC_MOUNT},mp=/mnt/data
lxc.idmap: u 0 100000 ${MAP_UID}
lxc.idmap: u ${MAP_UID} ${MAP_UID} 1
lxc.idmap: u ${UID_AFTER} ${UID_HOST_AFTER} ${UID_REMAINING}
lxc.idmap: g 0 100000 ${MAP_GID}
lxc.idmap: g ${MAP_GID} ${MAP_GID} 1
lxc.idmap: g ${GID_AFTER} ${GID_HOST_AFTER} ${GID_REMAINING}
EOF

# -- Restart the container -----------------------------------------------------
info "Restarting container $CTID..."
pct reboot "$CTID"

# Wait for container to be fully running before pushing files
info "Waiting for container $CTID to come up..."
TIMEOUT=30
ELAPSED=0
while [[ "$(pct status "$CTID" 2>/dev/null)" != *"running"* ]]; do
    if [[ $ELAPSED -ge $TIMEOUT ]]; then
        error "Container $CTID did not start within ${TIMEOUT}s."
        exit 1
    fi
    sleep 1
    ((ELAPSED++))
done
info "Container $CTID is running."

# -- Push and run setup_container_user.sh inside the container -----------------
info "Setting up user '${USERNAME}' inside container $CTID..."
pct push "$CTID" "${SCRIPT_DIR}/setup_container_user.sh" /tmp/setup_container_user.sh
pct exec "$CTID" -- chmod +x /tmp/setup_container_user.sh
pct exec "$CTID" -- /tmp/setup_container_user.sh "${USERNAME}" "${MAP_UID}" "${MAP_GID}"

# Cleanup
pct exec "$CTID" -- rm -f /tmp/setup_container_user.sh
info "Cleanup complete."

info "All done! Container $CTID is configured and user '${USERNAME}' is ready."