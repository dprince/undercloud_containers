source stackrc

scp ironic-python-agent.initramfs root@$SEED_IP:/httpboot/agent.ramdisk
scp ironic-python-agent.kernel root@$SEED_IP:/httpboot/agent.kernel

OS_IMAGE_API_VERSION=1 openstack overcloud image upload #loads deploy kernel and ramdisk
openstack baremetal import --json ~/testenv.json

for X in $(ironic node-list | grep 'None' | cut -d ' ' -f 2); do
  ironic node-update $X add driver_info/deploy_forces_oob_reboot=True
done
#ironic node-update optiplex add driver_info/deploy_forces_oob_reboot=True

#OS_IMAGE_API_VERSION=2 load-image -d overcloud-full.qcow2
openstack baremetal configure boot

#glance image-create --name centos-atomic --file CentOS-Atomic-Host-7.1.2-GenericCloud.qcow2 --disk-format qcow2 --container-format bare

bash flavors.sh

nova keypair-add --pub-key ~/.ssh/id_rsa.pub default

#openstack baremetal introspection bulk start
bash ~/puppet.sh

