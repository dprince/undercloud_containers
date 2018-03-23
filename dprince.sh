#!/usr/bin/env bash
set -eux

cat > $HOME/custom.yaml <<-EOF_CAT
parameter_defaults:
  DockerIronicConductorImage: 172.19.0.2:8787/master/centos-binary-ironic-conductor:iboot
  DockerKeepalivedImage: 172.19.0.2:8787/tripleoupstream/centos-binary-keepalived:latest
  DockerKeepalivedConfigImage: 172.19.0.2:8787/tripleoupstream/centos-binary-keepalived:latest
  DockerTripleoUIImage: 172.19.0.2:8787/master/centos-binary-tripleo-ui:tripleo-ci-testing
  DockerTripleoUIConfigImage: 172.19.0.2:8787/master/centos-binary-tripleo-ui:tripleo-ci-testing
  DockerPuppetProcessCount: 6
  DockerNamespace: 172.19.0.2:8787/tripleoupstream
  DockerNamespaceIsRegistry: true
  IronicEnabledHardwareTypes: idrac,ilo,ipmi,redfish,staging-iboot
  IronicEnabledPowerInterfaces: idrac,ilo,ipmitool,redfish,staging-iboot
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
undercloud_debug=false
network_gateway = 172.19.0.1
network_cidr = 172.19.0.0/24
dhcp_start = 172.19.0.6
dhcp_end = 172.19.0.20
inspection_iprange=172.19.0.21,172.19.0.40
#enabled_drivers=
enable_ironic=true
enable_ironic_inspector=true
enable_zaqar=true
enable_mistral=true
enable_validations=true
custom_env_files=/home/stack/custom.yaml,/home/stack/tripleo-heat-templates/environments/services-docker/tripleo-ui.yaml
docker_insecure_registries=172.19.0.2:8787
generate_service_certificate=false
undercloud_public_host = 172.19.0.4
undercloud_admin_host = 172.19.0.5
container_images_file=/home/stack/containers.yaml
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
