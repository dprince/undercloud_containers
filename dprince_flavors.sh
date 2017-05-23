# custom flavors for dprince's "Minibox's"
openstack flavor create --id auto --ram 16384 --disk 105 --vcpus 1 minibox
openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:hardware_label"="minibox" minibox
