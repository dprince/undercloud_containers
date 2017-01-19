#!/usr/bin/env bash
set -ux

virsh destroy seed

# call into scripts from tripleo-incubator (add these to your $PATH)
cleanup-env
setup-seed-vm -a amd64 -m 12388608 -c 6
sudo cp instack.qcow2 /var/lib/libvirt/images/seed.qcow2
virsh start seed
sleep 15

SEED_IP=$(sudo cat /var/lib/libvirt/dnsmasq/virbr0.status | grep ip-address | tail -n 1 | sed -e "s|.*ip-address\": \"\([^\"]*\).*|\1|")

ssh root@${SEED_IP} < doit.sh

