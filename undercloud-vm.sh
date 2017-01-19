# Build an undercloud VM with DIB and install it into the local
# libvirt images dir
disk-image-create --image-size 30 -a amd64 rdo-release centos7 vm local-config package-installs -o undercloud.qcow2
sudo cp undercloud.qcow2 /var/lib/libvirt/images/seed.qcow2
sudo chattr +C /var/lib/libvirt/images/seed.qcow2 || true
