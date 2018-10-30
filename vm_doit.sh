#!/usr/bin/env bash
set -ux

if [[ "$USER" == 'dprince' ]]; then
VM_IP=172.19.0.3
else
VM_IP=${VM_IP:?"Please define a VM IP?"}
fi

if [[ "$USER" == 'dprince' ]]; then
ssh stack@${VM_IP} <<EOF_SSH
sudo echo "undercloud.localdomain" > /etc/hostname
sudo echo "127.0.0.1  undercloud undercloud.localdomain" >> /etc/hosts
sudo hostname undercloud.localdomain
LOCAL_IP=172.19.0.3
LOCAL_REGISTRY="172.19.0.2:8787"
$(cat doit.sh)
$(cat dprince.sh)
EOF_SSH
else
    ssh stack@${VM_IP} < doit.sh
fi
