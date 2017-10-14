#!/usr/bin/env bash
set -eux

cat > $HOME/custom.yaml <<-EOF_CAT
parameter_defaults:
  UndercloudDhcpRangeStart: 172.19.0.4
  UndercloudDhcpRangeEnd: 172.19.0.20
  UndercloudNetworkCidr: 172.19.0.0/24
  UndercloudNetworkGateway: 172.19.0.1
  UndercloudNameserver: 8.8.8.8
  IronicEnabledDrivers: ['pxe_iboot_iscsi']
  #IronicAutomatedCleaning: false
  NeutronDhcpAgentsPerNetwork: 2
  NeutronWorkers: 3
  NeutronServicePlugins: ""

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

cat > $HOME/run.sh <<-EOF_CAT
time sudo openstack undercloud deploy --templates=$HOME/tripleo-heat-templates \\
--heat-native \\
--local-ip=$LOCAL_IP \\
--heat-container-image=172.19.0.2:8787/tripleoupstream/centos-binary-heat-all \\
-e $HOME/tripleo-heat-templates/environments/services-docker/ironic.yaml \\
-e $HOME/tripleo-heat-templates/environments/services-docker/mistral.yaml \\
-e $HOME/tripleo-heat-templates/environments/services-docker/zaqar.yaml \\
-e $HOME/tripleo-heat-templates/environments/docker.yaml \\
-e $HOME/custom.yaml -e $HOME/containers.yaml \\
-e $HOME/tripleo-heat-templates/environments/config-download-environment.yaml \\
| tee openstack_undercloud_deploy.out | lolcat
EOF_CAT
#-e $HOME/tripleo-heat-templates/environments/puppet-pacemaker.yaml \
chmod 755 $HOME/run.sh

openstack overcloud container image prepare --namespace=172.19.0.2:8787/tripleoupstream --env-file=$HOME/containers.yaml
#overcloud container image prepare --namespace=trunk.registry.rdoproject.org/tripleo --env-file=/root/rdo.yaml

# Redirect console for AMT ttyS1 (dprince uses amtterm this way)
#sed -e 's|text|text console=ttyS1,115200|' -i /usr/lib/python2.7/site-packages/ironic/drivers/modules/ipxe_config.template
