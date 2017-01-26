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

  DockerNamespace: 172.19.0.2:8787/tripleo
  DockerNamespaceIsRegistry: true
EOF_CAT

# use this guy to run ad-hoc mysql queries for troubleshooting
cat > $HOME/mysql_helper.sh <<-EOF_CAT
#!/usr/bin/env bash
docker run -ti \
--user root \
--volume /var/lib/kolla/config_files/mysql.json:/var/lib/kolla/config_files/config.json \
--volume /var/lib/config-data/mysql/:/var/lib/kolla/config_files/src:ro \
--volume /var/lib/config-data/mysql/root:/root/:ro \
--volume /etc/hosts:/etc/hosts:ro \
--volume mariadb:/var/lib/mysql/ \
172.19.0.2:8787/tripleo/centos-binary-mariadb /bin/bash
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
