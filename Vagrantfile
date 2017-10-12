# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2" if not defined? VAGRANTFILE_API_VERSION

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.define "o3container-vm"
  config.vm.hostname = "o3container-vm"

  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = "centos/7"

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  #config.vm.synced_folder ".", "/vagrant", type: "nfs"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #

  config.vm.provider "libvirt" do |domain, override|
    domain.memory = 12288
    domain.cpus = 4
    domain.nested = true
  end

  config.vm.provider "virtualbox" do |vb, override|
  #   # Display the VirtualBox GUI when booting the machine
  #   vb.gui = true
  #
  #   # Customize the amount of memory on the VM:
    vb.memory = 12288
    vb.cpus = 4
  end

  ## Provisioning

  #config.vm.provision "file", source: "", destination: "/etc/yum.repos.d/download.devel.redhat.com.repo"
  config.vm.provision "file", source: "./undercloud.conf", destination: "$HOME/undercloud.conf"

  config.vm.provision "shell", inline: <<-SHELL
    yum update -y
    yum install -y epel-release
    yum install -y git docker
  SHELL

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    cd /vagrant
    ./doit.sh
    cd $HOME
    sed -i 's,OS::TripleO::Undercloud::Net::SoftwareConfig:.*,OS::TripleO::Undercloud::Net::SoftwareConfig: ../net-config-noop.yaml,' tripleo-heat-templates/environments/undercloud.yaml
    ./run.sh
  SHELL

end
