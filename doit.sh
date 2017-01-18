#!/usr/bin/env bash
set -ux

virsh destroy seed

# call into scripts from tripleo-incubator (add these to your $PATH)
cleanup-env 
setup-seed-vm -a amd64 -m 12388608 -c 6
sudo cp instack.qcow2 /var/lib/libvirt/images/seed.qcow2
virsh start seed
sleep 15

SEED_IP=$(sudo cat /var/lib/libvirt/dnsmasq/virbr0.status | grep ip-address | tail -n 1 | sed -e "s|.*ip-address\": \"\([^\"]*\).*|\1|")

ssh root@${SEED_IP} <<-EOF

setenforce permissive

set -eux

pushd /etc/yum.repos.d/
rm delorean.repo
rm delorean-deps.repo

yum -y install wget vim-enhanced
pushd /etc/yum.repos.d/
wget http://trunk.rdoproject.org/centos7/delorean-deps.repo
sudo sed -i -e 's|priority=.*|priority=30|' /etc/yum.repos.d/delorean-deps.repo
wget http://trunk.rdoproject.org/centos7/current/delorean.repo
yum install -y epel-release openvswitch

yum install -y https://dprince.fedorapeople.org/tmate-2.2.1-1.el7.centos.x86_64.rpm

git config --global user.email "you@example.com"
git config --global user.name "Your Name"

popd

sudo yum install -y openstack-heat-api openstack-heat-engine python-heat-agent-hiera python-heat-agent-apply-config python-heat-agent-puppet python-ipaddr python-tripleoclient bridge-utils openstack-ceilometer-api python-heat-agent-docker-cmd openstack-ironic-staging-drivers docker
cd

systemctl start openvswitch
echo "INSECURE_REGISTRY='--insecure-registry 172.19.0.2:8787'" > /etc/sysconfig/docker
systemctl start docker

sudo rm -Rf /usr/lib/python2.7/site-packages/python_tripleoclient-*
sudo ln -f -s /usr/share/openstack-puppet/modules/* /etc/puppet/modules/

# TRIPLEO HEAT TEMPLATES
cd
git clone git://git.openstack.org/openstack/tripleo-heat-templates
cd tripleo-heat-templates

#Add deployed server bootstrap to noop-ctlplane
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/86/421586/1 && git cherry-pick FETCH_HEAD

# docker: eliminate copy-json.py in favor of json-file
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/20/416420/15 && git cherry-pick FETCH_HEAD

# docker: new hybrid deployment architecture and configuration
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/21/416421/22 && git cherry-pick FETCH_HEAD

# revert cells DB revert
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/99/421999/1 && git cherry-pick FETCH_HEAD

# enable docker services in the registry
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/67/421567/1 && git cherry-pick FETCH_HEAD

# Add Rabbit to the endpoint map
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/20/420920/8 && git cherry-pick FETCH_HEAD

# Nova
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/21/420921/9 && git cherry-pick FETCH_HEAD

# Heat
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/39/417639/17 && git cherry-pick FETCH_HEAD

# Ironic
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/17/421517/1 && git cherry-pick FETCH_HEAD

# Keystone
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/05/416605/23 && git cherry-pick FETCH_HEAD

# Glance
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/70/400870/40 && git cherry-pick FETCH_HEAD

# MySQL
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/01/414601/22 && git cherry-pick FETCH_HEAD
#sed -e '/.*MySQL/d' -i /root/tripleo-heat-templates/environments/docker.yaml

# TRIPLEO_CLIENT
cd
git clone git://git.openstack.org/openstack/python-tripleoclient
cd python-tripleoclient/
git fetch https://git.openstack.org/openstack/python-tripleoclient refs/changes/51/351351/18 && git checkout FETCH_HEAD
sudo python setup.py install

cd
git clone git://git.openstack.org/openstack/heat-agents
cd heat-agents

# Implement container_step_config for containers
git fetch https://git.openstack.org/openstack/heat-agents refs/changes/23/420723/7 && git cherry-pick FETCH_HEAD

sudo cp heat-config-json-file/install.d/hook-json-file.py /usr/libexec/heat-config/hooks/json-file
sudo cp heat-config-docker-cmd/install.d/hook-docker-cmd.py /usr/libexec/heat-config/hooks/docker-cmd

cd /etc/puppet/modules
rm -f mysql
git clone https://github.com/dprince/puppetlabs-mysql.git mysql
cd mysql
git checkout -b noop_providers remotes/origin/noop_providers
cd

cat > /root/tripleo-undercloud-passwords.yaml <<-EOF_CAT
parameter_defaults:
  AdminPassword: HnTzjCGP6HyXmWs9FzrdHRxMs
EOF_CAT

cat > /root/custom.yaml <<-EOF_CAT
parameter_defaults:
  UndercloudDhcpRangeStart: 172.19.0.4
  UndercloudDhcpRangeEnd: 172.19.0.20
  UndercloudNetworkCidr: 172.19.0.0/24
  UndercloudNetworkGateway: 172.19.0.1
  UndercloudNameserver: 8.8.8.8
  IronicEnabledDrivers: ['pxe_iboot_iscsi']
  IronicAutomatedCleaning: false
  NeutronDhcpAgentsPerNetwork: 2
  NeutronWorkers: 3

  DockerNamespace: 172.19.0.2:8787/dprince
  DockerNamespaceIsRegistry: true
EOF_CAT

cat > /root/run.sh <<-EOF_CAT

# swap in your local IP here
openstack undercloud deploy --templates=/root/tripleo-heat-templates \
--local-ip=172.19.0.3 \
-e /root/tripleo-heat-templates/environments/services/ironic.yaml \
-e /root/tripleo-heat-templates/environments/services/mistral.yaml \
-e /root/tripleo-heat-templates/environments/services/zaqar.yaml \
-e /root/tripleo-heat-templates/environments/docker.yaml \
-e /root/custom.yaml
EOF_CAT

#bash /root/run.sh

#cat >> /etc/ironic/ironic.conf <<-EOF_CAT
#[iboot]
#max_retry=10
#retry_interval=5
#reboot_delay=8
#EOF_CAT

# Redirect console for AMT ttyS1
#sed -e 's|text|text console=ttyS1,115200|' -i /usr/lib/python2.7/site-packages/ironic/drivers/modules/ipxe_config.template

#systemctl restart openstack-ironic-api
#systemctl restart openstack-ironic-conductor

EOF
exit 0

source stackrc

scp ironic-python-agent.initramfs root@$SEED_IP:/httpboot/agent.ramdisk
scp ironic-python-agent.kernel root@$SEED_IP:/httpboot/agent.kernel

OS_IMAGE_API_VERSION=1 openstack overcloud image upload #loads deploy kernel and ramdisk
openstack baremetal import --json ~/testenv.json

for X in $(ironic node-list | grep 'None' | cut -d ' ' -f 2); do
  ironic node-update $X add driver_info/deploy_forces_oob_reboot=True
done
#ironic node-update optiplex add driver_info/deploy_forces_oob_reboot=True

#OS_IMAGE_API_VERSION=2 load-image -d overcloud-full.qcow2
openstack baremetal configure boot

#glance image-create --name centos-atomic --file CentOS-Atomic-Host-7.1.2-GenericCloud.qcow2 --disk-format qcow2 --container-format bare

bash flavors.sh

nova keypair-add --pub-key ~/.ssh/id_rsa.pub default

#openstack baremetal introspection bulk start
bash ~/puppet.sh
