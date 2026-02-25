#!/bin/bash
set -euo pipefail

# Usage: ./setup_container_user.sh [USERNAME] [UID] [GID]
#   USERNAME  - name for the new user       (default: media)
#   UID       - user ID                     (default: 1028)
#   GID       - group ID                    (default: 100 / 'users')

# -- Colours -------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# -- Root check ----------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root."
    exit 1
fi

# -- Arguments -----------------------------------------------------------------
USERNAME="${1:-media}"
USER_UID="${2:-1028}"
USER_GID="${3:-100}"

info "Setting up user '${USERNAME}' with UID=${USER_UID}, GID=${USER_GID}"

# -- 1. Create group (idempotent) ----------------------------------------------
if getent group "${USER_GID}" >/dev/null 2>&1; then
    EXISTING_GROUP="$(getent group "${USER_GID}" | cut -d: -f1)"
    warn "Group with GID ${USER_GID} already exists ('${EXISTING_GROUP}'), skipping."
else
    if [[ "${USER_GID}" -eq 100 ]]; then
        GROUP_NAME="users"
    else
        GROUP_NAME="${USERNAME}"
    fi
    groupadd -g "${USER_GID}" "${GROUP_NAME}"
    info "Created group '${GROUP_NAME}' (GID ${USER_GID})."
fi

# -- 2. Create user (idempotent) -----------------------------------------------
if id "${USERNAME}" >/dev/null 2>&1; then
    warn "User '${USERNAME}' already exists, skipping creation."
else
    useradd -u "${USER_UID}" -g "${USER_GID}" -m -s /bin/bash "${USERNAME}"
    info "Created user '${USERNAME}' (UID ${USER_UID})."
fi

# -- 3. Fix home directory ownership -------------------------------------------
mkdir -p "/home/${USERNAME}"
chown "${USER_UID}:${USER_GID}" "/home/${USERNAME}"
info "Home directory /home/${USERNAME} ownership set."

# -- 4. Verify NFS mount access ------------------------------------------------
if [[ -d /mnt/data ]]; then
    if su - "${USERNAME}" -c "touch /mnt/data/lxc_setup_complete.txt" 2>/dev/null; then
        info "Verification passed — wrote /mnt/data/lxc_setup_complete.txt"
    else
        warn "Could not write to /mnt/data — check mount and permissions."
    fi
else
    warn "/mnt/data does not exist yet — skipping write verification."
fi

info "User '${USERNAME}' setup complete."