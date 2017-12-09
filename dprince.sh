#!/usr/bin/env bash
set -eux

cat > $HOME/custom.yaml <<-EOF_CAT
parameter_defaults:
  DockerPuppetProcessCount: 6
  DockerNamespace: 172.19.0.2:8787/tripleoupstream
  DockerNamespaceIsRegistry: true
  Debug: true
  UndercloudExtraConfig:
    ironic::conductor::cleaning_disk_erase: 'metadata'
    ironic::conductor::cleaning_network: 'ctlplane'
    ironic::conductor::automated_clean: false
    ironic::config::ironic_config:
      iboot/max_retry:
        value: 10
      iboot/retry_interval:
        value: 5
      iboot/reboot_delay:
        value: 8
    zaqar::max_messages_post_size: 1048576
EOF_CAT

cat > $HOME/undercloud.conf <<-EOF_CAT
[DEFAULT]
heat_native=true
local_ip=$LOCAL_IP/24
heat_container_image=172.19.0.2:8787/tripleoupstream/centos-binary-heat-all
undercloud_nameservers = 8.8.8.8
network_gateway = 172.19.0.1
network_cidr = 172.19.0.0/24
dhcp_start = 172.19.0.4
dhcp_end = 172.19.0.20
inspection_iprange=172.19.0.21,172.19.0.40
enabled_drivers=pxe_iboot_iscsi
enable_ironic=true
enable_ironic_inspector=true
enable_zaqar=true
enable_mistral=true
custom_env_files=/home/stack/containers.yaml,/home/stack/custom.yaml
dhcp_start=172.19.0.200
dhcp_end=172.19.0.205
docker_insecure_registries=172.19.0.2:8787
EOF_CAT
chmod 755 $HOME/run.sh

#openstack overcloud container image prepare --namespace=172.19.0.2:8787/tripleoupstream --env-file=$HOME/containers.yaml
#overcloud container image prepare --namespace=trunk.registry.rdoproject.org/tripleo --env-file=/root/rdo.yaml
openstack overcloud container image prepare \
  --tag tripleo-ci-testing \
  --namespace 172.19.0.2:8787/master \
  --output-env-file=$HOME/containers.yaml \
  --template-file $HOME/tripleo-common/container-images/overcloud_containers.yaml.j2 \
  -r $HOME/tripleo-heat-templates/roles_data_undercloud.yaml

# Redirect console for AMT ttyS1 (dprince uses amtterm this way)
#sed -e 's|text|text console=ttyS1,115200|' -i /usr/lib/python2.7/site-packages/ironic/drivers/modules/ipxe_config.template
