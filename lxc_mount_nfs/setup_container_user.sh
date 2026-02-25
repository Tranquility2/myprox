#!/bin/bash
# Inside the LXC
# Usage: ./setup_container_user.sh [USERNAME] [UID] [GID]
#   USERNAME  - name for the new user       (default: media)
#   UID       - user ID                     (default: 1028)
#   GID       - group ID                    (default: 100 / 'users')

USERNAME="${1:-media}"
USER_UID="${2:-1028}"
USER_GID="${3:-100}"

echo "Setting up user '${USERNAME}' with UID=${USER_UID}, GID=${USER_GID}"

# 1. Create the group (if it doesn't already exist) and the user
groupadd -g "${USER_GID}" users 2>/dev/null
useradd -u "${USER_UID}" -g "${USER_GID}" -m -s /bin/bash "${USERNAME}"

# 2. Fix home directory ownership (essential for 'su -' login)
mkdir -p "/home/${USERNAME}"
chown "${USER_UID}:${USER_GID}" "/home/${USERNAME}"

# 3. Final verification
su - "${USERNAME}" -c "touch /mnt/data/lxc_setup_complete.txt" && echo "Success!"