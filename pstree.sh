#!/bin/sh

watch -n 1 "pstree -alU `ps a | grep 'openstack undercloud' | grep -v grep | awk '{ print $1 }' | head -n 1`"

