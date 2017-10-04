#!/usr/bin/env bash
set -eux

read -p "This script cleans up all your local repositories. Are you sure? " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    cd
    sudo rm -rf custom.yaml heat-agents tripleo-common python-tripleoclient run.sh tripleo-heat-templates tripleo-undercloud-passwords.yaml
fi
