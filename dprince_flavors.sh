# custom flavors for dprince's "Minibox's"
openstack flavor create --id auto --ram 16384 --disk 105 --vcpus 1 dell_optiplex
openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:hardware_label"="dell_optiplex" dell_optiplex
openstack flavor create --id auto --ram 16384 --disk 105 --vcpus 1 intel_nuc
openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:hardware_label"="intel_nuc" intel_nuc
