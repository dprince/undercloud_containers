#!/usr/bin/env bash
set -x

REGISTRY=${REGISTRY:?"Please specify a registry"}
NAMESPACE=${NAMESPACE:-"tripleo"}
TAG=${TAG:-"latest"}

sudo yum install -y python-virtualenv gcc

cd
if [ ! -d kolla ]; then
  git clone https://github.com/openstack/kolla.git
fi
cd kolla
git checkout master
git pull origin master
virtualenv ~/kolla-venv
source ~/kolla-venv/bin/activate
pip install -U pip
pip install -r requirements.txt

cat > template_overrides.j2 <<-EOF_CAT
{% extends parent_template %}
{% set base_centos_binary_packages_append = ['puppet'] %}
{% set nova_scheduler_packages_append = ['openstack-tripleo-common'] %}

# Required for mistral-db-populate to load tripleo custom actions
{% set mistral_api_packages_append = ['openstack-tripleo-common'] %}

# FIXME (kolla review to add ceilometer to swift proxy image)
{% set swift_proxy_server_packages_append = ['openstack-ceilometer-common'] %}

# Fix missing directories in mariadb image
{% block mariadb_footer %}
RUN mkdir -p /var/lib/mysql && \
  chmod 755 /var/lib/mysql && \
  chown mysql.mysql /var/lib/mysql && \
  mkdir -p /var/log/mariadb && \
  chmod 750 /var/log/mariadb && \
  chown mysql.mysql /var/log/mariadb && \
  mkdir -p /var/run/mariadb && \
  chmod 755 /var/run/mariadb && \
  chown mysql.mysql /var/run/mariadb
{% endblock %}
EOF_CAT

if [ "$USER" == 'dprince' ]; then
cat >> template_overrides.j2 <<-EOF_CAT
{% set ironic_conductor_packages_append = ['openstack-ironic-staging-drivers', 'http://fedorapeople.org/~dprince/fedora/python-iboot-0.1.0-999.fc20.noarch.rpm'] %}
EOF_CAT
fi

./tools/build.py \
  --base centos \
  --type binary \
  --namespace "$NAMESPACE" \
  --registry "$REGISTRY" \
  --tag "$TAG" \
  --push \
  --template-override template_overrides.j2 \
  $@
cd
deactivate
