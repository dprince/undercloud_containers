#!/usr/bin/env bash
set -x

sudo docker ps -qa | xargs sudo docker rm -f
echo 'drop database keystone;' | sudo mysql -u root
echo 'drop database glance;' | sudo mysql -u root
echo 'drop database heat;' | sudo mysql -u root
echo 'drop database nova;' | sudo mysql -u root
echo 'drop database nova_api;' | sudo mysql -u root
echo 'drop database nova_api_cell0;' | sudo mysql -u root
