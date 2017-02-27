#!/usr/bin/env bash
set -x

REGISTRY=${REGISTRY:?"Please specify a registry"}
NAMESPACE=${NAMESPACE:-"tripleo"}
TAG=${TAG:-"latest"}

# NOTE: we set this to build from master packages for TripleO
# rather than the older RDO tested pin often which doesn't contain the latest
cat > /tmp/kolla-build.conf <<-EOF_CAT
[DEFAULT]
# Comma separated list of .rpm or .repo file(s) or URL(s) to install
# before building containers (list value)
#rpm_setup_config = http://buildlogs.centos.org/centos/7/cloud/x86_64/rdo-trunk-master-tested/delorean.repo,http://trunk.rdoproject.org/centos7/delorean-deps.repo
rpm_setup_config = http://trunk.rdoproject.org/centos7/current/delorean.repo,http://trunk.rdoproject.org/centos7/delorean-deps.repo
EOF_CAT

cd

curl -L -o /tmp/kolla_template_overrides.j2 http://git.openstack.org/cgit/openstack/tripleo-common/plain/contrib/tripleo_kolla_template_overrides.j2

# Ironic removed drivers from the main tree so we add them
# back here per developer
if [ "$USER" == 'dprince' ]; then
cat >> /tmp/kolla_template_overrides.j2 <<-EOF_CAT
{% set ironic_conductor_packages_append = ['openstack-ironic-staging-drivers', 'http://fedorapeople.org/~dprince/fedora/python-iboot-0.1.0-999.fc20.noarch.rpm'] %}
EOF_CAT
fi

kolla-build \
  --base centos \
  --config-file=/home/dprince/kolla/kolla-build.conf \
  --type binary \
  --namespace "$NAMESPACE" \
  --registry "$REGISTRY" \
  --tag "$TAG" \
  --template-override /tmp/kolla_template_overrides.j2 \
  $@
