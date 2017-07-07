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

cd
git clone https://git.openstack.org/openstack/tripleo-repos
cd tripleo-repos
sudo ./setup.py install
cd
sudo tripleo-repos current

sudo yum -y update

# these avoid warning for the cherry-picks below ATM
if [ ! -f $HOME/.gitconfig ]; then
  git config --global user.email "theboss@foo.bar"
  git config --global user.name "TheBoss"
fi

sudo yum clean all
sudo yum install -y \
  python-heat-agent \
  python-heat-agent-ansible \
  python-heat-agent-hiera \
  python-heat-agent-apply-config \
  python-heat-agent-docker-cmd \
  python-heat-agent-json-file \
  python-heat-agent-puppet python-ipaddr \
  python-tripleoclient \
  docker \
  docker-distribution \
  openvswitch \
  openstack-puppet-modules
cd

sudo systemctl start openvswitch
sudo systemctl enable openvswitch

sudo mkdir -p /etc/puppet/modules/
sudo ln -f -s /usr/share/openstack-puppet/modules/* /etc/puppet/modules/
sudo mkdir -p /etc/puppet/hieradata/
sudo tee /etc/puppet/hieradata/docker_setup.yaml /etc/puppet/hiera.yaml <<-EOF_CAT
---
:backends:
  - yaml
:yaml:
  :datadir: /etc/puppet/hieradata
:hierarchy:
  - docker_setup
EOF_CAT

echo "step: 5" | sudo tee /etc/puppet/hieradata/docker_setup.yaml
if [ -n "$LOCAL_REGISTRY" ]; then
  echo "tripleo::profile::base::docker::docker_namespace: $LOCAL_REGISTRY" | sudo tee -a /etc/puppet/hieradata/docker_setup.yaml
  echo "tripleo::profile::base::docker::insecure_registry: True" | sudo tee -a /etc/puppet/hieradata/docker_setup.yaml
fi

sudo puppet apply --modulepath /etc/puppet/modules --execute "include ::tripleo::profile::base::docker"

# TRIPLEO HEAT TEMPLATES
cd
git clone git://git.openstack.org/openstack/tripleo-heat-templates
cd tripleo-heat-templates

# Support configurable Zaqar backends
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/59/477559/12 && git checkout FETCH_HEAD

# Drop MongoDB from the undercloud
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/62/477562/9 && git cherry-pick FETCH_HEAD

# Fix ironic-pxe startup issues
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/43/481343/1 && git cherry-pick FETCH_HEAD

# PUPPET-TRIPLEO
cd /etc/puppet/modules
rm tripleo
git clone git://git.openstack.org/openstack/puppet-tripleo tripleo
cd tripleo

# this is how you inject an admin password
cat > $HOME/tripleo-undercloud-passwords.yaml <<-EOF_CAT
parameter_defaults:
  AdminPassword: HnTzjCGP6HyXmWs9FzrdHRxMs
EOF_CAT

# Custom settings can go here
if [[ ! -f $HOME/custom.yaml ]]; then
cat > $HOME/custom.yaml <<-EOF_CAT
parameter_defaults:
  UndercloudNameserver: 8.8.8.8
  NeutronServicePlugins: ""
EOF_CAT
fi

LOCAL_IP=${LOCAL_IP:-`/usr/sbin/ip -4 route get 8.8.8.8 | awk {'print $7'} | tr -d '\n'`}

# run this to cleanup containers and volumes between iterations
cat > $HOME/cleanup.sh <<-EOF_CAT
#!/usr/bin/env bash
set -x

sudo docker ps -qa | xargs sudo docker rm -f
sudo docker volume ls -q | xargs sudo docker volume rm
sudo rm -Rf /var/lib/mysql
sudo rm -Rf /var/lib/rabbitmq
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
-e $HOME/tripleo-heat-templates/environments/services-docker/ironic.yaml \
-e $HOME/tripleo-heat-templates/environments/services-docker/mistral.yaml \
-e $HOME/tripleo-heat-templates/environments/services-docker/zaqar.yaml \
-e $HOME/tripleo-heat-templates/environments/docker.yaml \
-e $HOME/custom.yaml
EOF_CAT
chmod 755 $HOME/run.sh

echo 'You will want to add "OS::TripleO::Undercloud::Net::SoftwareConfig: ../net-config-noop.yaml" to tripleo-heat-templates/environments/undercloud.yaml if you have a single nic.'
