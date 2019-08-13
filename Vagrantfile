#!/usr/bin/ruby

OCP_CPU = 2
OCP_MEMORY = 2048

###########################################################################

Vagrant.require_version ">= 1.9.2"
Vagrant.configure("2") do |config|

  config.vm.box = "centos/7"
  config.vm.box_check_update = false
  config.ssh.pty = true
  config.ssh.insert_key = false
#   config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.provider "virtualbox" do |v, override|
    v.gui = false
    v.memory = OCP_MEMORY
    v.cpus   = OCP_CPU
    v.customize ["modifyvm", :id, "--ioapic", "on"]
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  end


  config.vm.provision "shell", inline: <<-SHELL
    yum install -y epel-release
    yum install -y ansible
  SHELL
  end