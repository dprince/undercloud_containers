#!/usr/bin/env bash
set -x

REGISTRY=${REGISTRY:?"Please specify a registry"}
NAMESPACE=${NAMESPACE:-"tripleo"}
TAG=${TAG:-"latest"}

cd
git clone https://github.com/openstack/kolla.git
cd kolla

cat > template_overrides.j2 <<-EOF_CAT
{% extends parent_template %}

# Disable external repos
{% set base_yum_repo_files_override = [] %}
{% set base_yum_url_packages_override = [] %}
{% set base_yum_repo_keys_override = [] %}

{% set base_centos_binary_packages_append = ['puppet'] %}
{% set nova_scheduler_packages_append = ['openstack-tripleo-common'] %}

# Required for mistral-db-populate to load tripleo custom actions
{% set mistral_api_packages_append = ['openstack-tripleo-common'] %}

# FIXME (kolla review to add ceilometer to swift proxy image)
{% set swift_proxy_server_packages_append = ['openstack-ceilometer-common'] %}

# Use mariadb-server package
{% set mariadb_packages_remove = ['MariaDB-Galera-server', 'MariaDB-client'] %}
{% set mariadb_packages_append = ['mariadb-server'] %}

# We'll configure mariadb with galera.cnf
{% block mariadb_footer %}
RUN rm /etc/my.cnf.d/mariadb-server.cnf /etc/my.cnf.d/auth_gssapi.cnf
{% endblock %}
EOF_CAT

if [ "$USER" == 'dprince' ]; then
cat >> template_overrides.j2 <<-EOF_CAT
{% set ironic_conductor_packages_append = ['openstack-ironic-staging-drivers', 'http://fedorapeople.org/~dprince/fedora/python-iboot-0.1.0-999.fc20.noarch.rpm'] %}
EOF_CAT
fi

./kolla-build \
  --base centos \
  --type binary \
  --namespace "$NAMESPACE" \
  --registry "$REGISTRY" \
  --tag "$TAG" \
  --push \
  --template-override template-overrides.j2 \
  $@
