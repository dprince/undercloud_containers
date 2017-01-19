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

  DockerNamespace: 172.19.0.2:8787/dprince
  DockerNamespaceIsRegistry: true
EOF_CAT

#FIXME these settings are for baremetal and need to be migrated
# into containers for dprince
#cat >> /etc/ironic/ironic.conf <<-EOF_CAT
#[iboot]
#max_retry=10
#retry_interval=5
#reboot_delay=8
#EOF_CAT

# Redirect console for AMT ttyS1 (dprince uses amtterm this way)
#sed -e 's|text|text console=ttyS1,115200|' -i /usr/lib/python2.7/site-packages/ironic/drivers/modules/ipxe_config.template

#systemctl restart openstack-ironic-api
#systemctl restart openstack-ironic-conductor
