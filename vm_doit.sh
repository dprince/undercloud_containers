#!/usr/bin/env bash
set -ux

if [[ "$USER" == 'dprince' ]]; then
VM_IP=172.19.0.3
else
VM_IP=${VM_IP:?"Please define a VM IP?"}
fi

if [[ "$USER" == 'dprince' ]]; then
ssh root@${VM_IP} <<EOF_SSH
echo "undercloud.localdomain" > /etc/hostname
echo "127.0.0.1  undercloud undercloud.localdomain" >> /etc/hosts
hostname undercloud.localdomain
useradd stack
cat >> /etc/sudoers <<EOF_CAT
stack ALL=(ALL) NOPASSWD:ALL
EOF_CAT
su -l stack
LOCAL_IP=172.19.0.3
LOCAL_REGISTRY="172.19.0.2:8787"
$(cat doit.sh)
$(cat dprince.sh)
EOF_SSH
else
    ssh root@${VM_IP} < doit.sh
fi
