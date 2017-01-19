#!/usr/bin/env bash
set -x

sudo setenforce permissive

pushd /etc/yum.repos.d/
sudo rm delorean.repo
sudo rm delorean-deps.repo

sudo yum -y install wget vim-enhanced
pushd /etc/yum.repos.d/
sudo wget http://trunk.rdoproject.org/centos7/delorean-deps.repo
sudo sed -i -e 's|priority=.*|priority=30|' /etc/yum.repos.d/delorean-deps.repo
sudo wget http://trunk.rdoproject.org/centos7/current/delorean.repo
sudo yum install -y epel-release openvswitch

sudo yum install -y https://dprince.fedorapeople.org/tmate-2.2.1-1.el7.centos.x86_64.rpm

popd

sudo yum install -y openstack-heat-api openstack-heat-engine python-heat-agent-hiera python-heat-agent-apply-config python-heat-agent-puppet python-ipaddr python-tripleoclient bridge-utils openstack-ceilometer-api python-heat-agent-docker-cmd openstack-ironic-staging-drivers docker
cd

sudo systemctl start openvswitch
echo "INSECURE_REGISTRY='--insecure-registry 172.19.0.2:8787'" | sudo tee /etc/sysconfig/docker
sudo systemctl start docker

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

# MySQL NOT WORKING YET!
#git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/01/414601/22 && git cherry-pick FETCH_HEAD
sed -e '/.*MySQL/d' -i $HOME/tripleo-heat-templates/environments/docker.yaml

# Only run containerized roles for now to make it faster (and probably make it work..).
cat > roles_data_undercloud.yaml <<-EOF_CAT
- name: Undercloud # the 'primary' role goes first
  CountDefault: 1
  disable_constraints: True
  ServicesDefault:
    - OS::TripleO::Services::Ntp
    - OS::TripleO::Services::MySQL
    #- OS::TripleO::Services::MongoDb
    - OS::TripleO::Services::Keystone
    - OS::TripleO::Services::Apache
    - OS::TripleO::Services::RabbitMQ
    - OS::TripleO::Services::GlanceApi
    #- OS::TripleO::Services::SwiftProxy
    #- OS::TripleO::Services::SwiftStorage
    #- OS::TripleO::Services::SwiftRingBuilder
    - OS::TripleO::Services::Memcached
    - OS::TripleO::Services::HeatApi
    - OS::TripleO::Services::HeatApiCfn
    - OS::TripleO::Services::HeatEngine
    - OS::TripleO::Services::NovaApi
    #- OS::TripleO::Services::NovaPlacement
    - OS::TripleO::Services::NovaMetadata
    - OS::TripleO::Services::NovaScheduler
    - OS::TripleO::Services::NovaConductor
    #- OS::TripleO::Services::MistralEngine
    #- OS::TripleO::Services::MistralApi
    #- OS::TripleO::Services::MistralExecutor
    - OS::TripleO::Services::IronicApi
    - OS::TripleO::Services::IronicConductor
    - OS::TripleO::Services::NovaIronic
    #- OS::TripleO::Services::Zaqar
    #- OS::TripleO::Services::NeutronServer
    #- OS::TripleO::Services::NeutronApi
    #- OS::TripleO::Services::NeutronCorePlugin
    #- OS::TripleO::Services::NeutronOvsAgent
    #- OS::TripleO::Services::NeutronDhcpAgent
EOF_CAT

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
cd

#cd /etc/puppet/modules
#rm -f mysql
#git clone https://github.com/dprince/puppetlabs-mysql.git mysql
#cd mysql
#git checkout -b noop_providers remotes/origin/noop_providers
#cd

# this is how you inject an admin password
cat > $HOME/tripleo-undercloud-passwords.yaml <<-EOF_CAT
parameter_defaults:
  AdminPassword: HnTzjCGP6HyXmWs9FzrdHRxMs
EOF_CAT

cat > $HOME/custom.yaml <<-EOF_CAT
parameter_defaults:
  UndercloudDhcpRangeStart: 172.19.0.4
  UndercloudDhcpRangeEnd: 172.19.0.20
  UndercloudNetworkCidr: 172.19.0.0/24
  UndercloudNetworkGateway: 172.19.0.1
  UndercloudNameserver: 8.8.8.8
EOF_CAT

MYIP=`ip -4 route get 8.8.8.8 | awk {'print $7'} | tr -d '\n'`
echo $MY_IP

cat > $HOME/run.sh <<-EOF_CAT
sudo openstack undercloud deploy --templates=$HOME/tripleo-heat-templates \
--local-ip=$MYIP \
-e $HOME/tripleo-heat-templates/environments/services/ironic.yaml \
-e $HOME/tripleo-heat-templates/environments/services/mistral.yaml \
-e $HOME/tripleo-heat-templates/environments/services/zaqar.yaml \
-e $HOME/tripleo-heat-templates/environments/docker.yaml \
-e $HOME/custom.yaml
EOF_CAT

chmod 755 $HOME/run.sh

echo git config --global user.email "you@example.com"
echo git config --global user.name "Your Name"

echo 'You will want to add "OS::TripleO::Undercloud::Net::SoftwareConfig: ../net-config-noop.yaml" to tripleo-heat-templates/environments/undercloud.yaml if you have a single nic.'


