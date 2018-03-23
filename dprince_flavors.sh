# custom flavors for dprince's "Minibox's"


#openstack flavor create --id auto --ram 16384 --disk 105 --vcpus 1 dell_optiplex
#openstack flavor set --property cpu_arch=x86_64 --property capabilities:hardware_label=dell_optiplex dell_optiplex
#openstack flavor create --id auto --ram 16384 --disk 105 --vcpus 1 intel_nuc
#openstack flavor set --property cpu_arch=x86_64 --property capabilities:hardware_label=intel_nuc intel_nuc

RESOURCES='--property resources:CUSTOM_BAREMETAL=1 --property resources:DISK_GB=0 --property resources:MEMORY_MB=0 --property resources:VCPU=0 --property capabilities:boot_option=local'
SIZINGS='--ram 4096 --vcpus 1 --disk 40'
openstack flavor create $SIZINGS $RESOURCES --property capabilities:profile=compute --property capabilities:hardware_label=dell_optiplex dell_optiplex
openstack flavor create $SIZINGS $RESOURCES --property capabilities:profile=control --property capabilities:hardware_label=intel_nuc intel_nuc
