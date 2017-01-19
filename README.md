# undercloud\_containers

This set of scripts sets up and maintains (kinda) a containerized undercloud.  Most of the work is done by doit.sh which downloads all the repositories necessary with all the patches and software needed to make it work.  It also creates a ~/run.sh script which you can use to kick off the undercloud.  This script can be run as a user or as root.

doit.sh expects to be run on a centos 7 machine.

* doit.sh: The main script which sets up all the bits necessary to run the containerized undercloud.

* cleanup.sh: Cleans up git repos so you can do a fresh checkout of everything.  Should be able to run doit.sh again after running this.  **Make sure you don't have any local changes because this will delete them!**

* dprince.sh: If you're dprince you'll looooooove it!

* post\_intall.sh: Things to run after installation to setup a working undercloud.

* vm\_doit.sh: This sets up a VM and then runs the doit.sh script on it. Currently requires some setup scripts from tripleo-incubator, etc.
