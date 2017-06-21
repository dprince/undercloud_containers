source stackrc

# Manually copy these in because python-tripleoclient assumes it is
# on local disk and fails remotely
scp images/ironic-python-agent.initramfs root@172.19.0.3:/var/lib/ironic/httpboot/agent.ramdisk
scp images/ironic-python-agent.kernel root@172.19.0.3:/var/lib/ironic/httpboot/agent.kernel

cd images
openstack overcloud image upload #loads deploy kernel and ramdisk
cd -
openstack overcloud node import testenv.json --provide

for X in $(ironic node-list | grep 'None' | cut -d ' ' -f 2); do
  ironic node-update $X add driver_info/deploy_forces_oob_reboot=True
done

#OS_IMAGE_API_VERSION=2 load-image -d overcloud-full.qcow2
openstack baremetal configure boot

nova keypair-add --pub-key ~/.ssh/id_rsa.pub default

if [[ "$USER" == 'dprince' ]]; then
  bash undercloud_containers/dprince_flavors.sh
fi

#FIXME: add this once we get Ironic inspector added to t-h-t
#openstack baremetal introspection bulk start
