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

sudo yum -y install curl vim-enhanced telnet epel-release ruby rubygems yum-plugins-priorities deltarpm git
sudo yum -y install https://dprince.fedorapeople.org/tmate-2.2.1-1.el7.centos.x86_64.rpm

sudo gem install lolcat

# for tripleo-repos install:
sudo yum -y install python-setuptools python-requests

cd
git clone https://git.openstack.org/openstack/tripleo-repos
cd tripleo-repos
sudo python setup.py install
cd
#sudo tripleo-repos current
sudo tripleo-repos current-tripleo

sudo yum -y update

# these avoid warning for the cherry-picks below ATM
if [ ! -f $HOME/.gitconfig ]; then
  git config --global user.email "theboss@foo.bar"
  git config --global user.name "TheBoss"
fi

sudo yum clean all
sudo yum install -y python-tripleoclient

#sudo systemctl start openvswitch
#sudo systemctl enable openvswitch

#sudo mkdir -p /etc/puppet/modules/
#sudo ln -f -s /usr/share/openstack-puppet/modules/* /etc/puppet/modules/

# PYTHON TRIPLEOCLIENT
if [ ! -d $HOME/python-tripleoclient ]; then
  git clone git://git.openstack.org/openstack/python-tripleoclient
  cd python-tripleoclient

  sudo python setup.py install

  cd
fi

# TRIPLEO-COMMON
if [ ! -d $HOME/tripleo-common ]; then
  git clone git://git.openstack.org/openstack/tripleo-common
  cd tripleo-common

  sudo python setup.py install

fi

# TRIPLEO HEAT TEMPLATES
if [ ! -d $HOME/tripleo-heat-templates ]; then
  cd
  git clone git://git.openstack.org/openstack/tripleo-heat-templates
  cd tripleo-heat-templates

  # Crane: Add docker/services/crane.yaml
  # https://review.openstack.org/#/c/609508/
  git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/08/609508/3 && git cherry-pick FETCH_HEAD

fi

 #Puppet TripleO
 #if [ ! -d $HOME/puppet-tripleo ]; then
   #cd
   #git clone git://git.openstack.org/openstack/puppet-tripleo
   #cd puppet-tripleo

   #cd /usr/share/openstack-puppet/modules
   #sudo rm -Rf tripleo
   #sudo cp -a $HOME/puppet-tripleo tripleo
 #fi
sudo yum -y install http://fedorapeople.org/~dprince/puppet-crane-0.0.0-1.noarch.rpm

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
DEFAULT_ROUTE=${DEFAULT_ROUTE:-`/usr/sbin/ip -4 route get 8.8.8.8 | awk {'print $3'} | tr -d '\n'`}
NETWORK_CIDR=${NETWORK_CIDR:-`echo $DEFAULT_ROUTE/16`}
LOCAL_INTERFACE=${LOCAL_INTERFACE:-`route -n | grep "^0.0.0.0" | tr -s ' ' | cut -d ' ' -f 8 | head -n 1`}

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
time openstack undercloud install | tee openstack_undercloud_deploy.out | $cat
EOF_CAT
chmod 755 $HOME/run.sh

# FIXME: It's probably not always /8
cat > $HOME/undercloud.conf <<-EOF_CAT
[DEFAULT]
heat_native=true
local_ip=$LOCAL_IP/8
local_interface=$LOCAL_INTERFACE
network_cidr=$NETWORK_CIDR
network_gateway=$DEFAULT_ROUTE
enable_ironic=true
enable_ironic_inspector=true
enable_zaqar=true
enable_ui=true
enable_validations=true
enable_mistral=true
custom_env_files=$HOME/containers.yaml
EOF_CAT

# The current state of the world is:
#  - This one works and is being pushed to:
#openstack overcloud container image prepare --tag tripleo-ci-testing --namespace trunk.registry.rdoproject.org/master --env-file $HOME/containers-rdo.yaml
#  - This one doesn't work but it should (apparently auth issues):
#openstack overcloud container image prepare --tag passed-ci --namespace trunk.registry.rdoproject.org/master --env-file $HOME/containers-rdo.yaml
#  - This one works:
#openstack overcloud container image prepare --namespace=172.19.0.2:8787/tripleoupstream --env-file=$HOME/containers.yaml

openstack overcloud container image prepare \
  --tag current-tripleo \
  --namespace docker.io/tripleomaster \
  --output-env-file=$HOME/containers.yaml \
  --template-file $HOME/tripleo-common/container-images/overcloud_containers.yaml.j2 \
  -r $HOME/tripleo-heat-templates/roles_data_undercloud.yaml \
  -e $HOME/tripleo-heat-templates/environments/docker.yaml \
  -e $HOME/tripleo-heat-templates/environments/services/mistral.yaml \
  -e $HOME/tripleo-heat-templates/environments/services/ironic.yaml \
  -e $HOME/tripleo-heat-templates/environments/services/ironic-inspector.yaml \
  -e $HOME/tripleo-heat-templates/environments/services/tripleo-ui.yaml \
  -e $HOME/tripleo-heat-templates/environments/services/zaqar.yaml

set +x

echo 'You will want to add "OS::TripleO::Undercloud::Net::SoftwareConfig: ../net-config-noop.yaml" to tripleo-heat-templates/environments/undercloud.yaml if you have a single nic.'

echo 'The next step is to run ~/run.sh, which will create a heat deployment of your templates.'
