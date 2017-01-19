source stackrc

# Manually copy these in because python-tripleoclient assumes it is
# on local disk and fails remotely
#scp ironic-python-agent.initramfs root@$SEED_IP:/httpboot/agent.ramdisk
#scp ironic-python-agent.kernel root@$SEED_IP:/httpboot/agent.kernel

OS_IMAGE_API_VERSION=1 openstack overcloud image upload #loads deploy kernel and ramdisk
openstack baremetal import --json ~/testenv.json

for X in $(ironic node-list | grep 'None' | cut -d ' ' -f 2); do
  ironic node-update $X add driver_info/deploy_forces_oob_reboot=True
done

#OS_IMAGE_API_VERSION=2 load-image -d overcloud-full.qcow2
openstack baremetal configure boot

bash flavors.sh

nova keypair-add --pub-key ~/.ssh/id_rsa.pub default

#openstack baremetal introspection bulk start
bash ~/puppet.sh
