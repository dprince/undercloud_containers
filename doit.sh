#!/usr/bin/env bash
set -x

sudo setenforce permissive

# Uncomment this for quickstack.
# FIXME: This breaks can break non-quickstack environments...
# Workaround https://bugs.launchpad.net/tripleo-quickstart/+bug/1658030
#if [ ! -f /usr/libexec/os-apply-config/templates/var/run/heat-config/heat-config ]; then
  #sudo yum clean all
  #sudo yum -y reinstall python-heat-agent
#fi

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

sudo yum install -y \
  python-heat-agent \
  python-heat-agent-hiera \
  python-heat-agent-apply-config \
  python-heat-agent-puppet python-ipaddr \
  python-tripleoclient \
  python-heat-agent-docker-cmd \
  docker \
  openvswitch \
  openstack-puppet-modules \
  openstack-kolla
cd

sudo systemctl start openvswitch
if [ -n "$LOCAL_REGISTRY" ]; then
  echo "INSECURE_REGISTRY='--insecure-registry $LOCAL_REGISTRY'" | sudo tee /etc/sysconfig/docker
fi
sudo systemctl start docker

sudo mkdir -p /etc/puppet/modules/
sudo ln -f -s /usr/share/openstack-puppet/modules/* /etc/puppet/modules/

# Puppet Ironic (this is required for dprince who needs to customize
# Ironic configs via ExtraConfig settings.)
cd /etc/puppet/modules
rm tripleo
git clone git://git.openstack.org/openstack/puppet-tripleo tripleo
cd tripleo
#puppet-tripleo ::ironic::config to Ironic base profile
git fetch https://git.openstack.org/openstack/puppet-tripleo refs/changes/90/429290/1 && git cherry-pick FETCH_HEAD

# nova placement fixes
git fetch https://git.openstack.org/openstack/puppet-tripleo refs/changes/09/433109/1 && git cherry-pick FETCH_HEAD

# TRIPLEO HEAT TEMPLATES
cd
git clone git://git.openstack.org/openstack/tripleo-heat-templates
cd tripleo-heat-templates

# docker: new hybrid deployment architecture and configuration
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/21/416421/40 && git cherry-pick FETCH_HEAD

# Add docker_puppet_tasks initialization on primary node
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/65/426565/10 && git cherry-pick FETCH_HEAD

# Add option to diff containers after config stage. (Ian Main)
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/42/425442/1 && git cherry-pick FETCH_HEAD

# enable docker services in the registry
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/67/421567/13 && git cherry-pick FETCH_HEAD

# Nova
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/21/420921/17 && git cherry-pick FETCH_HEAD

# Nova Placement: Configure authtoken in nova-placement api service
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/11/433111/1 && git cherry-pick FETCH_HEAD

# Heat
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/39/417639/21 && git cherry-pick FETCH_HEAD

# Ironic
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/17/421517/8 && git cherry-pick FETCH_HEAD

# Keystone - now with logging to log volume
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/05/416605/34 && git cherry-pick FETCH_HEAD

# Glance
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/70/400870/43 && git cherry-pick FETCH_HEAD

# Neutron
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/99/422999/7 && git cherry-pick FETCH_HEAD

# Mistral
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/44/425744/4 && git cherry-pick FETCH_HEAD

# Mysql
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/01/414601/31 && git cherry-pick FETCH_HEAD

# Zaqar
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/76/425976/4 && git cherry-pick FETCH_HEAD

# Rabbitmq
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/12/426612/2 && git cherry-pick FETCH_HEAD

# Mongo
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/47/423347/6 && git cherry-pick FETCH_HEAD

# Memcached
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/46/428546/2 && git cherry-pick FETCH_HEAD

# Swift
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/34/425434/7 && git cherry-pick FETCH_HEAD

# parallelize docker-puppet
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/60/430460/2 && git cherry-pick FETCH_HEAD

# docker-toool:
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/46/431746/2 && git cherry-pick FETCH_HEAD

# TRIPLEO_CLIENT (uncomment this to hack on tripleoclient)
#cd
# REMOVE previously installed client stuff
# sudo rm -Rf /usr/lib/python2.7/site-packages/python_tripleoclient-*
#git clone git://git.openstack.org/openstack/python-tripleoclient
#cd python-tripleoclient/
## FETCH patches here...
#python setup.py install

# HEAT AGENTS
cd
git clone git://git.openstack.org/openstack/heat-agents
cd heat-agents

# Refactor docker invocation into function
git fetch https://git.openstack.org/openstack/heat-agents refs/changes/33/426633/2 && git cherry-pick FETCH_HEAD

# Set labels on containers managed by docker-cmd
git fetch https://git.openstack.org/openstack/heat-agents refs/changes/16/428516/3 && git cherry-pick FETCH_HEAD

# Delete containers based on labels, not state files
git fetch https://git.openstack.org/openstack/heat-agents refs/changes/67/430467/4 && git cherry-pick FETCH_HEAD

sudo cp heat-config-json-file/install.d/hook-json-file.py /usr/libexec/heat-config/hooks/json-file
sudo ln -sf $HOME/heat-agents/heat-config-docker-cmd/install.d/hook-docker-cmd.py /usr/libexec/heat-config/hooks/docker-cmd
sudo ln -sf $HOME/heat-agents/heat-config-docker-cmd/os-refresh-config/configure.d/50-heat-config-docker-cmd /usr/libexec/os-refresh-config/configure.d/50-heat-config-docker-cmd
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

LOCAL_IP=${LOCAL_IP:-`/usr/sbin/ip -4 route get 8.8.8.8 | awk {'print $7'} | tr -d '\n'`}

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
