#!/usr/bin/env bash
# This script is probably not POSIX-compliant, so using bash.

set -e
set -x

set -o allexport
VERNAME="${NAME}-v${VERSION}"
OVA_PATH="${NAME}-v${VERSION}.ova"
FULL_PATH="${VERNAME}/${VERNAME}"
VDI_PATH="${FULL_PATH}.vdi"
set +o allexport

./stages/initvm.sh

# Start the VM and scrub it!
./stages/spinupvm.sh

sshpass -p "${PASSWD}" ssh -p ${SSH_HOST_PORT} \
  -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
  root@localhost "bash -c \"
adduser \"${USER}\" vboxsf

cd /home/${USER}/.wallpapers/
rm *
wget ${WALLPAPERS}

rm -rf /var/cache/apt/*
rm -rf /var/lib/apt/lists/*
rm -rf /var/log/dpkg.log*
rm -rf /home/archimedes/.*_history

rm -rf /usr/lib/x86_64-linux-gnu-gallium-pipe
rm -rf /usr/lib/x86_64-linux-gnu/dri

dd if=/dev/zero of=/tmp/zero bs=1M
rm /tmp/zero
shutdown -h now
\""

./stages/spindownvm.sh

# Finally, compact the disk after the clean up:
vboxmanage modifyhd "${VDI_PATH}" --compact

./stages/exportova.sh

./stages/rmvm.sh
