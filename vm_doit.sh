#!/usr/bin/env bash
set -ux

virsh destroy seed

# call into scripts from tripleo-incubator (add these to your $PATH)
cleanup-env
setup-seed-vm -a amd64 -m 12388608 -c 6
sudo cp $HOME/undercloud.qcow2 /var/lib/libvirt/images/seed.qcow2
virsh start seed
sleep 15

SEED_IP=$(sudo cat /var/lib/libvirt/dnsmasq/virbr0.status | grep ip-address | tail -n 1 | sed -e "s|.*ip-address\": \"\([^\"]*\).*|\1|")

if [[ "$USER" == 'dprince' ]]; then
ssh root@${SEED_IP} <<EOF_SSH
echo "undercloud.localdomain" > /etc/hostname
echo "127.0.0.1  undercloud undercloud.localdomain" >> /etc/hosts
hostname undercloud
LOCAL_IP=172.19.0.3
LOCAL_REGISTRY="172.19.0.2:8787"
$(cat doit.sh)
$(cat dprince.sh)
EOF_SSH
else
    ssh root@${SEED_IP} < doit.sh
fi
