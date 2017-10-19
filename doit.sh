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

sudo yum -y install curl vim-enhanced telnet epel-release ruby rubygems yum-plugins-priorities deltarpm
sudo yum -y install https://dprince.fedorapeople.org/tmate-2.2.1-1.el7.centos.x86_64.rpm

sudo gem install lolcat

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
  openstack-tripleo-common \
  openstack-tripleo-heat-templates \
  openstack-puppet-modules \
  openstack-heat-common # required until the Heat patch below lands
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
  # config download support.  Checkout as it has deps.
  git fetch https://git.openstack.org/openstack/tripleo-common refs/changes/76/512876/2 && git checkout FETCH_HEAD

  sudo python setup.py install
  cd
fi

# PYTHON TRIPLEOCLIENT
if [ ! -d $HOME/python-tripleoclient ]; then
  git clone git://git.openstack.org/openstack/python-tripleoclient
  cd python-tripleoclient

  # Use ansible to deploy undercloud.
  # https://review.openstack.org/#/c/509586/
  git fetch https://git.openstack.org/openstack/python-tripleoclient refs/changes/86/509586/4 && git cherry-pick FETCH_HEAD

  # Remove fake keystone
  # https://review.openstack.org/509588
  git fetch https://git.openstack.org/openstack/python-tripleoclient refs/changes/88/510288/8 && git cherry-pick FETCH_HEAD

  # WIP: Mount a tmpfs filesystem for heat tmpfiles
  # https://review.openstack.org/#/c/508558/
  git fetch https://git.openstack.org/openstack/python-tripleoclient refs/changes/58/508558/3 && git cherry-pick FETCH_HEAD

  # Don't install RPMs during undercloud install.  Now done here in doit.sh.
  # https://review.openstack.org/#/c/510239/
  # FIXME this doesn't apply cleanly
  # git fetch https://git.openstack.org/openstack/python-tripleoclient refs/changes/39/510239/2 && git cherry-pick FETCH_HEAD

  # Support for undercloud install
  git fetch https://git.openstack.org/openstack/python-tripleoclient refs/changes/50/511350/8 && git cherry-pick FETCH_HEAD

  sudo python setup.py install
  cd
fi

# HEAT
if [ ! -d $HOME/heat ]; then
  git clone git://git.openstack.org/openstack/heat
  cd heat

  # Move FakeKeystoneClient to engine.clients
  # https://review.openstack.org/#/c/512035/
  git fetch https://git.openstack.org/openstack/heat refs/changes/35/512035/3 && git cherry-pick FETCH_HEAD

  # https://review.openstack.org/#/c/513007/
  # https://bugs.launchpad.net/heat/+bug/1724263
  git fetch https://git.openstack.org/openstack/heat refs/changes/07/513007/1 && git cherry-pick FETCH_HEAD

  sudo python setup.py install
  cd
fi


# TRIPLEO HEAT TEMPLATES
if [ ! -d $HOME/tripleo-heat-templates ]; then
  cd
  git clone git://git.openstack.org/openstack/tripleo-heat-templates
  cd tripleo-heat-templates

  # Our undercloud default nic should be eth1
  # https://review.openstack.org/#/c/510212/
  git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/12/510212/3 && git cherry-pick FETCH_HEAD

  # Add docker templates to configure Ironic inspector
  # https://review.openstack.org/#/c/457822/40
  git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/22/457822/40 && git cherry-pick FETCH_HEAD

fi

# os-net-config
if [ ! -d $HOME/os-net-config ]; then
  cd
  git clone git://git.openstack.org/openstack/os-net-config
  cd os-net-config

  # Allow dns_servers to be an empty array
  # https://review.openstack.org/#/c/510207/
  git fetch https://git.openstack.org/openstack/os-net-config refs/changes/07/510207/1 && git cherry-pick FETCH_HEAD

  sudo python setup.py install

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
  DockerPuppetProcessCount: 100
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
sudo rm -Rf /var/lib/heat-config/*
EOF_CAT
chmod 755 $HOME/cleanup.sh

if which lolcat &> /dev/null; then
  cat=lolcat
else
  cat=cat
fi

# FIXME how to generate tripleo-heat-templates/environments/config-download-environment.yaml?
cat > $HOME/run.sh <<-EOF_CAT
export THT_HOME=$HOME/tripleo-heat-templates
time openstack undercloud install --experimental \\
| tee openstack_undercloud_deploy.out | $cat
EOF_CAT
chmod 755 $HOME/run.sh

sed -i "s/@@LOCAL_IP@@/$LOCAL_IP/" $HOME/undercloud.conf
sed -i "s#@@CONTAINERS_FILE@@#$HOME/containers.yaml#" $HOME/undercloud.conf

# The current state of the world is:
#  - This one works and is being pushed to:
#openstack overcloud container image prepare --tag tripleo-ci-testing --namespace trunk.registry.rdoproject.org/master --env-file $HOME/containers-rdo.yaml
#  - This one doesn't work but it should (apparently auth issues):
#openstack overcloud container image prepare --tag passed-ci --namespace trunk.registry.rdoproject.org/master --env-file $HOME/containers-rdo.yaml
#  - This one works:
openstack overcloud container image prepare --namespace=172.19.0.2:8787/tripleoupstream --env-file=$HOME/containers.yaml

openstack overcloud container image prepare --tag passed-ci --namespace tripleopike --env-file $HOME/containers-rdo.yaml
# Note that there is a tripleo-ci-testing tag in dockerhub but it's not being updated.

set +x

echo 'You will want to add "OS::TripleO::Undercloud::Net::SoftwareConfig: ../net-config-noop.yaml" to tripleo-heat-templates/environments/undercloud.yaml if you have a single nic.'

echo 'The next step is to run ~/run.sh, which will create a heat deployment of your templates.'
