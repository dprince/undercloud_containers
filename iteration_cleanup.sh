#!/usr/bin/env bash
set -x

sudo docker ps -qa | xargs sudo docker rm -f
echo 'drop database keystone;' | mysql -u root
echo 'drop database glance;' | mysql -u root
echo 'drop database heat;' | mysql -u root
echo 'drop database nova;' | mysql -u root
echo 'drop database nova_api;' | mysql -u root
echo 'drop database nova_api_cell0;' | mysql -u root
