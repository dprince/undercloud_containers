#!/usr/bin/env bash
set -x

REGISTRY=${REGISTRY:?"Please specify a registry"}
NAMESPACE=${NAMESPACE:-"tripleo"}
TAG=${TAG:-"latest"}

# NOTE: we set this to build from master packages for TripleO
# rather than the older RDO tested pin often which doesn't contain the latest
cat > /tmp/kolla-build.conf <<-EOF_CAT
[DEFAULT]
base=centos
type=binary
# Comma separated list of .rpm or .repo file(s) or URL(s) to install
# before building containers (list value)
#rpm_setup_config = http://buildlogs.centos.org/centos/7/cloud/x86_64/rdo-trunk-master-tested/delorean.repo,http://trunk.rdoproject.org/centos7/delorean-deps.repo
rpm_setup_config = http://trunk.rdoproject.org/centos7/current-tripleo/delorean.repo,http://trunk.rdoproject.org/centos7/delorean-deps.repo

[profiles]
undercloud=glance,heat,ironic,keystone,mariadb,memcached,mistral,mongodb,neutron,nova,rabbitmq,swift,zaqar,aodh
EOF_CAT

cd

rm /tmp/kolla_template_overrides.j2
touch /tmp/kolla_template_overrides.j2

# Ironic removed drivers from the main tree so we add them
# back here per developer
if [ "$USER" == 'dprince' ]; then
cat >> /tmp/kolla_template_overrides.j2 <<-EOF_CAT
{% set ironic_conductor_packages_append = ['openstack-ironic-staging-drivers', 'http://fedorapeople.org/~dprince/fedora/python-iboot-0.1.0-999.fc20.noarch.rpm'] %}
EOF_CAT
fi

time kolla-build \
  --config-file=/tmp/kolla-build.conf \
  --namespace $NAMESPACE \
  --registry $REGISTRY \
  --tag $TAG \
  --template-override /usr/share/tripleo-common/container-images/tripleo_kolla_template_overrides.j2 \
  --template-override /tmp/kolla_template_overrides.j2 \
  $@
