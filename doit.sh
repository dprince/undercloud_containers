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

# for tripleo-repos install:
sudo yum -y install python-setuptools python-requests

cd
git clone https://git.openstack.org/openstack/tripleo-repos
cd tripleo-repos
sudo python setup.py install
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
  echo "tripleo::profile::base::docker::insecure_registry_address: $LOCAL_REGISTRY" | sudo tee -a /etc/puppet/hieradata/docker_setup.yaml
fi

cd
sudo puppet apply --modulepath /etc/puppet/modules --execute "include ::tripleo::profile::base::docker"

# TRIPLEO-COMMON
if [ ! -d $HOME/tripleo-common ]; then
  git clone git://git.openstack.org/openstack/tripleo-common
  cd tripleo-common
  # config download support - cherry-pick isn't working atm, conflicts..:
  git fetch https://git.openstack.org/openstack/tripleo-common refs/changes/89/508189/2 && git checkout FETCH_HEAD
  sudo python setup.py install
  cd
fi

# PYTHON TRIPLEOCLIENT
if [ ! -d $HOME/python-tripleoclient ]; then
  git clone git://git.openstack.org/openstack/python-tripleoclient
  cd python-tripleoclient

  # Make it so heat never exits
  git fetch https://git.openstack.org/openstack/python-tripleoclient refs/changes/19/508319/1 && git cherry-pick FETCH_HEAD

  sudo python setup.py install
  cd
fi

# TRIPLEO HEAT TEMPLATES
if [ ! -d $HOME/tripleo-heat-templates ]; then
  cd
  git clone git://git.openstack.org/openstack/tripleo-heat-templates
  cd tripleo-heat-templates

  #Sync undercloud stackrc w/ instack (fixes post deployment issues)
  git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/45/506745/1 && git cherry-pick FETCH_HEAD

  # Config download support for all deployment types:
  git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/27/505827/9 && git cherry-pick FETCH_HEAD

  # Name the post deployment so the ansible generator works:
  git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/51/508351/1 && git cherry-pick FETCH_HEAD
fi

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
time sudo openstack undercloud deploy \
--templates=$HOME/tripleo-heat-templates \
--local-ip=$LOCAL_IP \
--keep-running \
-e $HOME/tripleo-heat-templates/environments/services-docker/ironic.yaml \
-e $HOME/tripleo-heat-templates/environments/services-docker/mistral.yaml \
-e $HOME/tripleo-heat-templates/environments/services-docker/zaqar.yaml \
-e $HOME/tripleo-heat-templates/environments/docker.yaml \
-e $HOME/custom.yaml \
-e $HOME/containers-rdo.yaml \
-e $HOME/tripleo-heat-templates/environments/config-download-environment.yaml
EOF_CAT
chmod 755 $HOME/run.sh

# TEMPORARY!!  This all needs to end up in tripleoclient.
mkdir $HOME/playbooks

cat > $HOME/ansible.sh <<-'EOF_CAT'
~/tripleo-common/scripts/tripleo-config-download --stack-name undercloud --output-dir ~/playbooks
wd=`ls -1dc ~/playbooks/tripleo* | head -n 1`
echo using $wd
pushd $wd
time sudo ansible-playbook -i ~/playbooks/inventory deploy_steps_playbook.yaml -e role_name=Undercloud -e deploy_server_id=undercloud -e bootstrap_server_id=undercloud
# -e force=true
popd
EOF_CAT

chmod 755 $HOME/ansible.sh

cat > $HOME/playbooks/inventory <<-EOF_CAT
[targets]
overcloud ansible_connection=local

[Undercloud]
overcloud

[undercloud-undercloud-0]
overcloud
EOF_CAT

# The current state of the world is:
#  - This one works and is being pushed to:
#openstack overcloud container image prepare --tag tripleo-ci-testing --namespace trunk.registry.rdoproject.org/master --env-file $HOME/containers-rdo.yaml
#  - This one doesn't work but it should (apparently auth issues):
#openstack overcloud container image prepare --tag passed-ci --namespace trunk.registry.rdoproject.org/master --env-file $HOME/containers-rdo.yaml
#  - This one works:
openstack overcloud container image prepare --tag passed-ci --namespace tripleopike --env-file $HOME/containers-rdo.yaml
# Note that there is a tripleo-ci-testing tag in dockerhub but it's not being updated.

set +x

echo 'You will want to add "OS::TripleO::Undercloud::Net::SoftwareConfig: ../net-config-noop.yaml" to tripleo-heat-templates/environments/undercloud.yaml if you have a single nic.'

echo 'The next step is to run ~/run.sh, which will create a heat deployment of your templates.'
echo 'Once that completes, source the stackrc (in /root) and run ansible.sh to download and run the ansible playbooks.'
