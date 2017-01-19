# undercloud_containers

doit.sh: The main script which sets up a centos 7 machine with all the bits necessary to run the containerized undercloud.

cleanup.sh: Cleans up git repos so you can do a fresh checkout of everything.  Should be able to run doit.sh again after running this.  **Make sure you don't have any local changes because this will delete them!**

dprince.sh: If you're dprince you'll looooooove it!

test.sh: Things to run afterwards to see if it's working.

vm_doit.sh: This sets up a VM and then runs the doit.sh script on it.

iteration_cleanup.sh: Cleans up between runs of openstack undercloud deploy (typically run via ~/.run.sh).

