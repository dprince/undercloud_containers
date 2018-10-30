source stackrc
set -x

scp testenv.json root@172.19.0.3:/home/stack/
# Manually copy these in because python-tripleoclient assumes it is
# on local disk and fails remotely
scp images/ironic-python-agent.initramfs root@172.19.0.3:/var/lib/ironic/httpboot/agent.ramdisk
scp images/ironic-python-agent.kernel root@172.19.0.3:/var/lib/ironic/httpboot/agent.kernel

cd images
openstack overcloud image upload --update-existing #loads deploy kernel and ramdisk

#for X in $(ironic node-list | cut -d ' ' -f 2); do
#  openstack baremetal node delete $S
#done

cd -
openstack overcloud node import testenv.json --provide

for X in $(ironic node-list | grep 'dell' | cut -d ' ' -f 2); do
  ironic node-update $X add driver_info/deploy_forces_oob_reboot=True
  openstack baremetal node set $X --property capabilities=profile:compute,boot_option:local --management-interface noop
  openstack overcloud node configure $X
done
for X in $(ironic node-list | grep 'nuc' | cut -d ' ' -f 2); do
  openstack baremetal node set $X --property capabilities=profile:control,boot_option:local --management-interface noop
  openstack overcloud node configure $X
done

openstack keypair delete default
nova keypair-add --pub-key ~/.ssh/id_rsa.pub default

# custom flavors for dprince's environment
openstack flavor delete compute
openstack flavor delete control

RESOURCES='--property resources:CUSTOM_BAREMETAL=1 --property resources:DISK_GB=0 --property resources:MEMORY_MB=0 --property resources:VCPU=0 --property capabilities:boot_option=local'
SIZINGS='--ram 4096 --vcpus 1 --disk 40'
openstack flavor create $SIZINGS $RESOURCES --property capabilities:profile=compute compute
openstack flavor create $SIZINGS $RESOURCES --property capabilities:profile=control control

#FIXME: add this once we get Ironic inspector added to t-h-t
#openstack baremetal introspection bulk start
