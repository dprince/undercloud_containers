#!/usr/bin/env bash
set -x

sudo setenforce permissive

# Make sure we get all new stuff.  I was having an issue with yum caching.
sudo yum clean all

# Workaround https://bugs.launchpad.net/tripleo-quickstart/+bug/1658030
if [ ! -f /usr/libexec/os-apply-config/templates/var/run/heat-config/heat-config ]; then
  sudo yum -y reinstall python-heat-agent
fi

sudo yum -y install curl vim-enhanced telnet epel-release
sudo yum install -y https://dprince.fedorapeople.org/tmate-2.2.1-1.el7.centos.x86_64.rpm
sudo curl -L -o /etc/yum.repos.d/delorean-deps.repo  http://trunk.rdoproject.org/centos7/delorean-deps.repo
sudo sed -i -e 's|priority=.*|priority=30|' /etc/yum.repos.d/delorean-deps.repo
sudo curl -L -o /etc/yum.repos.d/delorean.repo http://trunk.rdoproject.org/centos7/current/delorean.repo

sudo yum -y update

# these avoid warning for the cherry-picks below ATM
if [ ! -f $HOME/.gitconfig ]; then
  git config --global user.email "theboss@foo.bar"
  git config --global user.name "TheBoss"
fi


sudo yum install -y python-heat-agent-hiera python-heat-agent-apply-config python-heat-agent-puppet python-ipaddr python-tripleoclient python-heat-agent-docker-cmd docker openvswitch
cd

sudo systemctl start openvswitch
if [ -n "$LOCAL_REGISTRY" ]; then
  echo "INSECURE_REGISTRY='--insecure-registry $LOCAL_REGISTRY'" | sudo tee /etc/sysconfig/docker
fi
sudo systemctl start docker

sudo rm -Rf /usr/lib/python2.7/site-packages/python_tripleoclient-*
sudo ln -f -s /usr/share/openstack-puppet/modules/* /etc/puppet/modules/

# TRIPLEO HEAT TEMPLATES
cd
git clone git://git.openstack.org/openstack/tripleo-heat-templates
cd tripleo-heat-templates

# docker: new hybrid deployment architecture and configuration
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/21/416421/34 && git cherry-pick FETCH_HEAD

# Add docker_puppet_tasks initialization on primary node
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/65/426565/4 && git cherry-pick FETCH_HEAD

# Add option to diff containers after config stage. (Ian Main)
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/42/425442/1 && git cherry-pick FETCH_HEAD

# enable docker services in the registry
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/67/421567/9 && git cherry-pick FETCH_HEAD

# Add Rabbit to the endpoint map
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/20/420920/11 && git cherry-pick FETCH_HEAD

# Nova
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/21/420921/13 && git cherry-pick FETCH_HEAD

# Heat
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/39/417639/19 && git cherry-pick FETCH_HEAD

# Ironic
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/17/421517/4 && git cherry-pick FETCH_HEAD

# Keystone
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/05/416605/30 && git cherry-pick FETCH_HEAD

# Glance
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/70/400870/42 && git cherry-pick FETCH_HEAD

# Neutron
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/99/422999/5 && git cherry-pick FETCH_HEAD

# Mistral
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/44/425744/2 && git cherry-pick FETCH_HEAD

# Mysql
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/01/414601/30 && git cherry-pick FETCH_HEAD

# Zaqar
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/76/425976/2 && git cherry-pick FETCH_HEAD

# Rabbitmq
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/12/426612/1 && git cherry-pick FETCH_HEAD

# Mongo
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/47/423347/5 && git cherry-pick FETCH_HEAD

# Only run containerized roles for now to make it faster (and probably make it work..).
cat > roles_data_undercloud.yaml <<-EOF_CAT
- name: Undercloud # the 'primary' role goes first
  CountDefault: 1
  disable_constraints: True
  ServicesDefault:
    - OS::TripleO::Services::Ntp #baremetal
    - OS::TripleO::Services::MySQL
    - OS::TripleO::Services::MongoDb
    - OS::TripleO::Services::Keystone
    - OS::TripleO::Services::Apache
    - OS::TripleO::Services::RabbitMQ
    - OS::TripleO::Services::GlanceApi
    #- OS::TripleO::Services::SwiftProxy
    #- OS::TripleO::Services::SwiftStorage
    #- OS::TripleO::Services::SwiftRingBuilder
    - OS::TripleO::Services::Memcached #baremetal
    - OS::TripleO::Services::HeatApi
    - OS::TripleO::Services::HeatApiCfn
    - OS::TripleO::Services::HeatEngine
    - OS::TripleO::Services::NovaApi
    #- OS::TripleO::Services::NovaPlacement
    - OS::TripleO::Services::NovaMetadata
    - OS::TripleO::Services::NovaScheduler
    - OS::TripleO::Services::NovaConductor
    - OS::TripleO::Services::MistralEngine
    - OS::TripleO::Services::MistralApi
    - OS::TripleO::Services::MistralExecutor
    - OS::TripleO::Services::IronicApi
    - OS::TripleO::Services::IronicConductor
    - OS::TripleO::Services::IronicPxe
    - OS::TripleO::Services::NovaIronic
    - OS::TripleO::Services::Zaqar
    - OS::TripleO::Services::NeutronApi
    - OS::TripleO::Services::NeutronCorePlugin
    - OS::TripleO::Services::NeutronOvsAgent
    - OS::TripleO::Services::NeutronDhcpAgent
EOF_CAT

# TRIPLEO_CLIENT
cd
git clone git://git.openstack.org/openstack/python-tripleoclient
cd python-tripleoclient/

# Add heat_launcher module to help launch heat-all
git fetch https://git.openstack.org/openstack/python-tripleoclient refs/changes/30/427530/2 && git cherry-pick FETCH_HEAD

# Add fake_keystone
git fetch https://git.openstack.org/openstack/python-tripleoclient refs/changes/31/427531/2 && git cherry-pick FETCH_HEAD

# Deploy the undercloud with Heat
git fetch https://git.openstack.org/openstack/python-tripleoclient refs/changes/51/351351/24 && git checkout FETCH_HEAD

# Add `--keep-running` flag to undercloud deploy
git fetch https://git.openstack.org/openstack/python-tripleoclient refs/changes/90/414490/1 && git cherry-pick FETCH_HEAD
sudo python setup.py install

cd
git clone git://git.openstack.org/openstack/heat-agents
cd heat-agents

# delete existing containers with the same name
git fetch https://git.openstack.org/openstack/heat-agents refs/changes/33/426633/1 && git cherry-pick FETCH_HEAD

sudo cp heat-config-json-file/install.d/hook-json-file.py /usr/libexec/heat-config/hooks/json-file
sudo cp heat-config-docker-cmd/install.d/hook-docker-cmd.py /usr/libexec/heat-config/hooks/docker-cmd
cd

# this is how you inject an admin password
cat > $HOME/tripleo-undercloud-passwords.yaml <<-EOF_CAT
parameter_defaults:
  AdminPassword: HnTzjCGP6HyXmWs9FzrdHRxMs
EOF_CAT

# Custom settings can go here
cat > $HOME/custom.yaml <<-EOF_CAT
parameter_defaults:
  UndercloudNameserver: 8.8.8.8
  NeutronServicePlugins: ""
EOF_CAT

LOCAL_IP=${LOCAL_IP:-`ip -4 route get 8.8.8.8 | awk {'print $7'} | tr -d '\n'`}

# run this to cleanup containers and volumes between iterations
cat > $HOME/cleanup.sh <<-EOF_CAT
#!/usr/bin/env bash
set -x

sudo docker ps -qa | xargs sudo docker rm -f
sudo docker volume ls -q | xargs sudo docker volume rm
EOF_CAT
chmod 755 $HOME/cleanup.sh

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
tripleoupstream/centos-binary-mariadb:latest /bin/bash
EOF_CAT
chmod 755 $HOME/mysql_helper.sh

cat > $HOME/run.sh <<-EOF_CAT
time sudo openstack undercloud deploy --templates=$HOME/tripleo-heat-templates \
--local-ip=$LOCAL_IP \
--keep-running \
-e $HOME/tripleo-heat-templates/environments/services/ironic.yaml \
-e $HOME/tripleo-heat-templates/environments/services/mistral.yaml \
-e $HOME/tripleo-heat-templates/environments/services/zaqar.yaml \
-e $HOME/tripleo-heat-templates/environments/docker.yaml \
-e $HOME/tripleo-heat-templates/environments/mongodb-nojournal.yaml \
-e $HOME/custom.yaml
EOF_CAT
chmod 755 $HOME/run.sh

echo 'You will want to add "OS::TripleO::Undercloud::Net::SoftwareConfig: ../net-config-noop.yaml" to tripleo-heat-templates/environments/undercloud.yaml if you have a single nic.'
